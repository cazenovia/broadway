namespace :baltimore do
  desc "Fetch parcels using a dynamic grid to permanently bypass API limits"
  task sync_parcels: :environment do
    require 'uri'
    require 'net/http'
    require 'json'
    require 'rgeo/geo_json'
    require 'set'

    # ==========================================
    # 🗺️ THE TRANSLATION DICTIONARY
    # Maps City 1-letter codes to your Frontend strings
    # ==========================================
    CITY_USAGE_MAP = {
      "R" => "Residential",
      "C" => "Commercial",
      "M" => "Mixed Use",
      "I" => "Industrial",
      "E" => "Exempt" # Often used for government/parks
    }.freeze

    # 🚨 REMOVED: Property.destroy_all 
    # We now update existing records instead of nuking the database!

    puts "📡 Connecting to OpenBaltimore...\n\n"

    base_url = "https://geodata.baltimorecity.gov/egis/rest/services/CityView/Realproperty_OB/FeatureServer/0/query"

    # THE DYNAMIC 12-BOX GRID
    min_x, max_x = -76.5995, -76.5890
    min_y, max_y = 39.2825, 39.2945

    x_steps = 3
    y_steps = 4
    x_size = (max_x - min_x) / x_steps.to_f
    y_size = (max_y - min_y) / y_steps.to_f
    overlap = 0.0002

    boxes = []
    (0...x_steps).each do |i|
      (0...y_steps).each do |j|
        bx_min = (min_x + (i * x_size) - overlap).round(5)
        bx_max = (min_x + ((i + 1) * x_size) + overlap).round(5)
        by_min = (min_y + (j * y_size) - overlap).round(5)
        by_max = (min_y + ((j + 1) * y_size) + overlap).round(5)
        boxes << "#{bx_min},#{by_min},#{bx_max},#{by_max}"
      end
    end

    saved_parcel_ids = Set.new
    total_api_features = 0

    boxes.each_with_index do |box, index|
      puts "=========================================================="
      puts "🔄 FETCHING GRID BOX #{index + 1} of #{boxes.length}"
      puts "=========================================================="
      
      url = URI(base_url)
      url.query = URI.encode_www_form(
        where: "1=1",
        geometry: box,      
        geometryType: "esriGeometryEnvelope",
        inSR: 4326,
        outSR: 4326,
        spatialRel: "esriSpatialRelIntersects",
        outFields: "*",
        f: "geojson"
      )

      response = Net::HTTP.get_response(url)

      if response.code != "200"
        abort("❌ API Error: #{response.code}\nServer said: #{response.body}")
      end

      data = JSON.parse(response.body)
      features = data['features']

      if features.nil? || features.empty?
        puts "⚠️ WARNING: OpenBaltimore returned 0 features for this box!"
        next
      end

      puts "📦 OpenBaltimore returned #{features.length} raw features. Parsing...\n\n"
      total_api_features += features.length

      features.each do |feature|
        props = feature['properties']
        
        rgeo_feature = RGeo::GeoJSON.decode(feature)
        geom = rgeo_feature.geometry
        
        address = props['FULLADDR'] || props['fulladdr'] || "Unknown Address"
        upcase_address = address.upcase

        if geom.nil?
          puts "  [🛑 SKIPPED - NO SHAPE]      | #{address}"
          next
        end

        parcel_id = feature['id'] || props['OBJECTID'] || props['objectid'] || "#{address}-#{geom.to_s.hash}"

        if saved_parcel_ids.include?(parcel_id)
          next
        end

        saved_parcel_ids.add(parcel_id)

        # THE SMART FILTER (Odd/Even Trimming)
        unwanted_streets = ["FAYETTE", "FLEET", "WOLFE", "CENTRAL"]
        if unwanted_streets.any? { |street| upcase_address.include?(street) }
          puts "  [🚧 SKIPPED - BLACKLISTED]   | #{address} (Fell on unwanted street)"
          next 
        end

        house_number = upcase_address.to_i 

        if house_number > 0
          if upcase_address.include?("EDEN") && house_number.even?
            puts "  [✂️ SKIPPED - EDEN WEST]     | #{address} (Even # on West Boundary)"
            next
          end
          if upcase_address.include?("ANN") && house_number.odd?
            puts "  [✂️ SKIPPED - ANN EAST]      | #{address} (Odd # on East Boundary)"
            next
          end
          if upcase_address.include?("EASTERN") && house_number.odd?
            puts "  [✂️ SKIPPED - EASTERN SOUTH] | #{address} (Odd # on South Boundary)"
            next
          end
          if upcase_address.include?("FAIRMOUNT") && house_number.even?
            puts "  [✂️ SKIPPED - FAIRMOUNT NORTH]| #{address} (Even # on North Boundary)"
            next
          end
        end

        # ==========================================
        # 🧩 THE TRANSLATION FIX
        # ==========================================
        raw_code = (props['USEGROUP'] || props['usegroup']).to_s.strip
        usage = CITY_USAGE_MAP[raw_code] || raw_code
        usage = "Mixed-Use" if usage.blank? # Fallback if API sends nothing

        owner = props['OWNER_1'] || props['owner_1'] || "Unknown"
        year = props['YEAR_BUILD'] || props['year_build'] || props['YEAR_BUILT'] || props['year_built']
        price = props['SALEPRIC'] || props['salepric']
        
        raw_date = props['SALEDATE'] || props['saledate']
        parsed_date = nil
        
        if raw_date.is_a?(String) && raw_date.strip.length == 8
          begin
            parsed_date = Date.strptime(raw_date.strip, "%m%d%Y")
          rescue StandardError
            parsed_date = nil 
          end
        end

        # ==========================================
        # 🛡️ THE UPSERT FIX (Safe Saving)
        # ==========================================
        # This finds an existing property by its address. If it doesn't exist, it builds a new one.
        property = Property.find_or_initialize_by(address: address)
        
        # Determine if we are updating or creating for the logger
        action_log = property.new_record? ? "✅ CREATED" : "🔄 UPDATED"

        # Update the API fields (leaving user-entered things like resident counts untouched)
        property.assign_attributes(
          usage_type: usage,
          owner: owner,
          boundary: geom,
          year_built: year,
          sale_price: price,
          sale_date: parsed_date
        )

        property.save!

        puts "  [#{action_log}]            | #{address} (#{usage})"
      end
    end

    puts "\n=========================================================="
    puts "🎉 SYNC COMPLETE!"
    puts "Total Raw Features from API: #{total_api_features}"
    puts "Total Properties in DB:      #{Property.count}"
    puts "==========================================================\n"
  end
end