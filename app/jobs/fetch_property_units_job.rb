require 'net/http'
require 'uri'
require 'json'

class FetchPropertyUnitsJob < ApplicationJob
  queue_as :default

  def perform(property_id)
    property = Property.find_by(id: property_id)
    return unless property

    search_address = property.address.to_s.upcase.strip

    base_url = "https://geodata.baltimorecity.gov/egis/rest/services/CityView/Realproperty_OB/FeatureServer/0/query"
    
    query_params = {
      where: "FULLADDR LIKE '#{search_address}%'", 
      outFields: "FULLADDR, DHCD_NO_DWELLING", 
      returnGeometry: "false",
      f: "json",
      resultRecordCount: 1
    }

    url = URI(base_url)
    url.query = URI.encode_www_form(query_params)

    # --- THE FIX: Robust HTTP Request with Redirect Handling ---
    response = Net::HTTP.get_response(url)

    # If the server responds with a 301 or 302 redirect, follow it
    if response.is_a?(Net::HTTPRedirection)
      redirect_url = URI(response['location'])
      # Sometimes redirects drop the query parameters, so we re-attach them
      redirect_url.query = url.query unless redirect_url.query
      response = Net::HTTP.get_response(redirect_url)
    end

    # If we didn't get a 200 OK after following redirects, abort safely
    unless response.is_a?(Net::HTTPSuccess)
      Rails.logger.error "⚠️ API Error #{response.code} for #{property.address}: #{response.message}"
      return
    end

    # Note: We use response.body here because get_response returns an object, not just a string
    data = JSON.parse(response.body)
    # -----------------------------------------------------------

    if data["features"] && data["features"].any?
      attributes = data["features"].first["attributes"]
      
      units = attributes["DHCD_NO_DWELLING"].to_i 
      estimated_pop = (units * 2.4).round

      if property.residential_units.blank?
        property.update!(
          residential_units: units,
          estimated_residents: estimated_pop
        )
        Rails.logger.info "✅ Updated #{property.address}: #{units} units, ~#{estimated_pop} residents."
      else
        Rails.logger.info "⏭️ Skipped #{property.address}: Already has manually entered data."
      end
    else
      Rails.logger.info "⚠️ No multi-family data found for #{property.address}."
    end

  rescue JSON::ParserError => e
    Rails.logger.error "❌ JSON Parse failed for #{property.address}. Response might not be JSON."
  rescue StandardError => e
    Rails.logger.error "❌ FetchPropertyUnitsJob failed for Property #{property_id}: #{e.message}"
  end
end