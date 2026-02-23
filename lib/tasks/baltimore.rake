namespace :baltimore do
  desc "Fetch parcels using 4 overlapping stripes to bypass 1000-record API limits"
  task sync_parcels: :environment do
    require 'uri'
    require 'net/http'
    require 'json'
    require 'rgeo/geo_json'
    require 'set'

    puts "\n🗑️  Clearing old test polygons..."
    Property.destroy_all

    puts "📡 Connecting to OpenBaltimore...\n\n"

    base_url = "https://geodata.baltimorecity.gov/egis/rest/services/CityView/Realproperty_OB/FeatureServer/0/query"

    # 4 HORIZONTAL STRIPES (Moving from South to North)
    # The overlaps are significantly widened here to ensure NO gaps between stripes!
    boxes = [
      "-76.5995,39.2825,-76.5890,39.2865", # Stripe 1: Eastern Ave to roughly Gough St
      "-76.5995,39.2855,-76.5890,39.2895", # Stripe 2: Gough St to Pratt St
      "-76.5995,39.2885,-76.5890,39.2920", # Stripe 3: Pratt St to Baltimore St
      "-76.5995,39.2910,-76.5890,39.2945"  # Stripe 4: Baltimore St up to Fairmount Ave
    ]

    saved_addresses = Set.new
    total_api_features = 0

    boxes.each_with_index do |box, index|
      puts "=========================================================="
      puts "🔄 FETCHING STRIPE #{index + 1} of 4"
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

      # 🔍 VERBOSE: Print the exact API URL
      puts "🔗 API Request URL: #{url}\n\n"

      response = Net::HTTP.get_response(url)

      if response.code != "200"
        abort("❌ API Error: #{response.code}\nServer said: #{response.body}")
      end

      data = JSON.parse(response.body)
      features = data['features']

      if features.nil? || features.empty?
        puts "⚠️ WARNING: OpenBaltimore returned 0 features for this stripe!"
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
          puts "  [🛑 SKIPPED - NO SHAPE]      | #{address} (API provided no polygon)"
          next
        end

        if saved_addresses.include?(upcase_address)
          puts "  [♻️ SKIPPED - DUPLICATE]     | #{address} (Caught in overlap)"
          next
        end

        # ==========================================
        # 🛡️ THE SMART FILTER (Odd/Even Trimming)
        # ==========================================
        
        unwanted_streets = ["FAYETTE", "FLEET", "WOLFE", "CENTRAL"]
        if unwanted_streets.any? { |street| upcase_address.include?(street) }
          puts "  [🚧 SKIPPED - BLACKLISTED]   | #{address} (Fell on unwanted street)"
          next 
        end

        house_number = upcase_address.to_i 

        if house_number > 0
          # N/S STREETS: West side is Even, East side is Odd
          if upcase_address.include?("EDEN") && house_number.even?
            puts "  [✂️ SKIPPED - EDEN WEST]     | #{address} (Even # on West Boundary)"
            next
          end
          if upcase_address.include?("ANN") && house_number.odd?
            puts "  [✂️ SKIPPED - ANN EAST]      | #{address} (Odd # on East Boundary)"
            next
          end

          # E/W STREETS: North side is Even, South side is Odd
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

        usage = props['USEGROUP'] || props['usegroup'] || "Mixed-Use"
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

        Property.create!(
          address: address,
          usage_type: usage,
          owner: owner,
          boundary: geom,
          year_built: year,
          sale_price: price,
          sale_date: parsed_date
        )

        saved_addresses.add(upcase_address)
        puts "  [✅ SAVED TO DATABASE]       | #{address}"
      end
    end

    puts "\n=========================================================="
    puts "🎉 IMPORT COMPLETE!"
    puts "Total Raw Features from API: #{total_api_features}"
    puts "Total Properties Saved:      #{Property.count}"
    puts "==========================================================\n"
  end
end