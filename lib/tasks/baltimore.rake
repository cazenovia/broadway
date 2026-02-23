namespace :baltimore do
  desc "Fetch real parcel boundaries from Open Baltimore with precise address filtering"
  task sync_parcels: :environment do
    require 'uri'
    require 'net/http'
    require 'json'
    require 'rgeo/geo_json'

    puts "🗑️  Clearing old test polygons..."
    Property.destroy_all

    puts "📡 Connecting to Open Baltimore..."

    base_url = "https://geodata.baltimorecity.gov/egis/rest/services/CityView/Realproperty_OB/FeatureServer/0/query"
    
    offset = 0
    batch_size = 1000
    total_fetched = 0

    loop do
      puts "🔄 Fetching batch starting at offset #{offset}..."
      
      url = URI(base_url)
      
      # THE BIG NET: Oversized to guarantee we catch the slanted southeast corner!
      # West: -76.5995, South: 39.2825, East: -76.5890, North: 39.2945
      url.query = URI.encode_www_form(
        where: "1=1",
        geometry: "-76.5995,39.2825,-76.5890,39.2945",      
        geometryType: "esriGeometryEnvelope",
        inSR: 4326,
        outSR: 4326,
        spatialRel: "esriSpatialRelIntersects",
        outFields: "*",
        f: "geojson",
        orderByFields: "OBJECTID ASC",
        resultOffset: offset,
        resultRecordCount: batch_size
      )

      response = Net::HTTP.get_response(url)

      if response.code != "200"
        abort("❌ API Error: #{response.code}\nServer said: #{response.body}")
      end

      data = JSON.parse(response.body)
      features = data['features']

      break if features.nil? || features.empty?

      features.each do |feature|
        props = feature['properties']
        
        rgeo_feature = RGeo::GeoJSON.decode(feature)
        geom = rgeo_feature.geometry
        
        next if geom.nil?

        address = props['FULLADDR'] || props['fulladdr'] || "Unknown Address"
        upcase_address = address.upcase

        # ==========================================
        # 🛡️ THE SMART FILTER (Odd/Even Trimming)
        # ==========================================
        
        # 1. Drop streets we absolutely know are outside our intended district
        unwanted_streets = ["FAYETTE", "ORLEANS", "FLEET", "ALICEANNA", "WOLFE", "WASHINGTON", "CENTRAL", "SPRING"]
        next if unwanted_streets.any? { |street| upcase_address.include?(street) }

        # Extract the house number (e.g., "123 S Ann St" -> 123)
        house_number = upcase_address.to_i 

        if house_number > 0
          # WEST BOUNDARY (Eden St): Keep East side (Odd). Drop Even.
          next if upcase_address.include?("EDEN") && house_number.even?
          
          # EAST BOUNDARY (Ann St): Keep West side (Even). Drop Odd.
          next if upcase_address.include?("ANN") && house_number.odd?

          # SOUTH BOUNDARY (Eastern Ave): Keep North side (Odd). Drop Even.
          next if upcase_address.include?("EASTERN") && house_number.even?

          # NORTH BOUNDARY (Fairmount Ave): Keep South side (Even). Drop Odd.
          next if upcase_address.include?("FAIRMOUNT") && house_number.odd?
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
      end
      
      total_fetched += features.length
      offset += batch_size
      
      break if features.length < batch_size
    end

    puts "🎉 Import complete! You now have #{Property.count} beautifully curated properties mapped."
  end
end