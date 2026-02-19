namespace :baltimore do
  desc "Fetch real parcel boundaries from Open Baltimore"
  task sync_parcels: :environment do
    require 'uri'
    require 'net/http'
    require 'json'
    require 'rgeo/geo_json'

    puts "🗑️  Clearing old test polygons..."
    Property.destroy_all

    puts "📡 Connecting to Open Baltimore..."

    # THE FIX: The ACTUAL endpoint for Baltimore's "Real Property" GeoService
    url = URI("https://geodata.baltimorecity.gov/egis/rest/services/CityView/Realproperty_OB/FeatureServer/0/query")

    # We use Ruby's built-in encoder, which safely handles everything
    url.query = URI.encode_www_form(
      where: "1=1",
      geometry: "-76.5945,39.2850,-76.5925,39.2915",     
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

    unless data['features'] && data['features'].any?
      abort("❌ Failed to fetch data. No features returned. (Check your bounding box!)")
    end

    puts "✅ Found #{data['features'].length} parcels! Saving to database..."

    data['features'].each do |feature|
      props = feature['properties']
      
      rgeo_feature = RGeo::GeoJSON.decode(feature)
      geom = rgeo_feature.geometry
      
      next if geom.nil?

# ArcGIS GeoJSON sometimes downcases column names, so we safely check both
      address = props['FULLADDR'] || props['fulladdr'] || "Unknown Address"
      usage = props['USEGROUP'] || props['usegroup'] || "Mixed-Use"
      owner = props['OWNER_1'] || props['owner_1'] || "Unknown"
      
      year = props['YEAR_BUILD'] || props['year_build'] || props['YEAR_BUILT'] || props['year_built']
      
      # FIX 1: The column is actually SALEPRIC (Missing the 'E')
      price = props['SALEPRIC'] || props['salepric']
      
      # FIX 2: Parse the 8-character "MMDDYYYY" string into a real Ruby Date
      raw_date = props['SALEDATE'] || props['saledate']
      parsed_date = nil
      
      if raw_date.is_a?(String) && raw_date.strip.length == 8
        begin
          parsed_date = Date.strptime(raw_date.strip, "%m%d%Y")
        rescue StandardError
          parsed_date = nil # Failsafe if the city has a bad date entry like "00000000"
        end
      end

      property = Property.new(
        address: address,
        usage_type: usage,
        owner: owner,
        boundary: geom,
        year_built: year,
        sale_price: price,
        sale_date: parsed_date
      )
      
      property.save!
    end

    puts "🎉 Import complete! You now have #{Property.count} actual properties mapped."
  end
end