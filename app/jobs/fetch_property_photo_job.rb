require 'open-uri'

class FetchPropertyPhotoJob < ApplicationJob
  queue_as :default

  def perform(property_id)
    property = Property.find_by(id: property_id)
    return unless property
    
    # 1. Skip if the property already has a photo
    return if property.photo.attached?

    # 2. Grab the key directly from the environment
    api_key = ENV.fetch('GOOGLE_MAPS_API_KEY')
    
    # 3. Format the address specifically for Baltimore
    search_address = "#{property.address.to_s.strip}, Baltimore, MD"
    encoded_address = URI.encode_uri_component(search_address)

    # 4. Build the API Request (return_error_code=true prevents downloading generic "No Image" graphics)
    url = "https://maps.googleapis.com/maps/api/streetview?size=600x400&location=#{encoded_address}&fov=90&pitch=0&return_error_code=true&key=#{api_key}"

    begin
      downloaded_image = URI.open(url)

      property.photo.attach(
        io: downloaded_image, 
        filename: "property_#{property.id}_streetview.jpg", 
        content_type: "image/jpeg"
      )
      
      Rails.logger.info "📸 Attached Street View photo for #{property.address}"
      
    rescue KeyError
      Rails.logger.error "🛑 CRITICAL: GOOGLE_MAPS_API_KEY is missing from environment variables!"
    rescue OpenURI::HTTPError => e
      Rails.logger.error "⚠️ No Street View imagery available for #{property.address}: #{e.message}"
    rescue StandardError => e
      Rails.logger.error "❌ Failed to fetch photo for #{property.address}: #{e.message}"
    end
  end
end