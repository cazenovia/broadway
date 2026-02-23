namespace :baltimore do
  desc "Fetch parcels using split bounding boxes to bypass broken API pagination"
  task sync_parcels: :environment do
    require 'uri'
    require 'net/http'
    require 'json'
    require 'rgeo/geo_json'
    require 'set'

    puts "🗑️  Clearing old test polygons..."
    Property.destroy_all

    puts "📡 Connecting to Open Baltimore..."

    base_url = "https://geodata.baltimorecity.gov/egis/rest/services/CityView/Realproperty_OB/FeatureServer/0/query"

    # Split the district in half (North/South) to guarantee < 1000 records per API call!
    boxes = [
      "-76.5980,39.2838,-76.5900,39.2887", # South Half (Eastern Ave to Pratt St)
      "-76.5980,39.2887,-76.5900,39.2936"  # North Half (Pratt St to Fairmount Ave)
    ]

    saved_addresses = Set.new

    boxes.each_with_index do |box, index|
      puts "🔄 Fetching Box #{index + 1} of 2..."
      
      url = URI(base_url)
      
      # NO PAGINATION PARAMETERS! Just fetch the raw box!
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

      next if features.nil? || features.empty?

      features.each do |feature|
        props = feature['properties']
        
        rgeo_feature = RGeo::GeoJSON.decode(feature)
        geom = rgeo_feature.geometry
        
        next if geom.nil?

        address = props['FULLADDR'] || props['fulladdr'] || "Unknown Address"
        upcase_address = address.upcase

        # Skip if we already saved this property (handles the overlap between the two boxes)
        next if saved_addresses.include?(upcase_address)

        # ==========================================
        # 🛡️ THE SMART FILTER (Odd/Even Trimming)
        # ==========================================
        
        # Hard drop streets we definitely don't want
        unwanted_streets = ["FAYETTE", "ORLEANS", "FLEET", "ALICEANNA", "WOLFE", "WASHINGTON", "CENTRAL", "SPRING"]
        next if unwanted_streets.any? { |street| upcase_address.include?(street) }

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

        saved_addresses.add(upcase_address)
      end
    end

    puts "🎉 Import complete! You now have #{Property.count} beautifully curated properties mapped."
  end
end