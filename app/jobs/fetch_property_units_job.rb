require 'net/http'
require 'uri'
require 'json'

class FetchPropertyUnitsJob < ApplicationJob
  queue_as :default

  def perform(property_id)
    property = Property.find_by(id: property_id)
    return unless property

    # 1. Format the address for the City API (usually all caps, e.g., "123 MAIN ST")
    search_address = property.address.to_s.upcase.strip

    # 2. Build the Socrata API Query for Baltimore City Open Data
    # Dataset 3scc-n3p9 is "Multiple Family Dwellings"
    # We use SoQL ($where) to search for the specific address
    encoded_query = URI.encode_www_form_component("property_address like '#{search_address}%'")
    url = URI("https://data.baltimorecity.gov/resource/3scc-n3p9.json?$where=#{encoded_query}&$limit=1")

    # 3. Fetch the data
    response = Net::HTTP.get(url)
    data = JSON.parse(response)

    # 4. Parse and Save
    if data.any?
      # Grab the units from the API response
      units = data.first["number_of_dwelling_units"].to_i
      
      # Multiply by the Baltimore average household size (approx. 2.4)
      estimated_pop = (units * 2.4).round

      # Only update if the property doesn't already have manually entered data
      property.update!(
        residential_units: units,
        estimated_residents: estimated_pop
      )
      
      Rails.logger.info "✅ Updated #{property.address}: #{units} units, ~#{estimated_pop} residents."
    else
      # If it's not in the multi-family database, it's likely a single-family home (1 unit)
      # You could choose to default it to 1 unit and 2 residents here if you wanted to!
      Rails.logger.info "⚠️ No multi-family data found for #{property.address}."
    end

  rescue StandardError => e
    Rails.logger.error "❌ FetchPropertyUnitsJob failed for Property #{property_id}: #{e.message}"
  end
end