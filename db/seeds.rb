# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end


# Clear old data
Property.destroy_all

puts "Seeding South Broadway..."

# Helper to make points
def point(lat, lon)
  "POINT(#{lon} #{lat})"
end

Property.create!([
  {
    address: "500 S Broadway",
    owner: "City of Baltimore",
    usage: "Public",
    notes: "Old market building, potential for mixed use.",
    lonlat: point(39.2855, -76.5938)
  },
  {
    address: "512 S Broadway",
    owner: "J. Smith LLC",
    usage: "Retail",
    notes: "Currently a vacant storefront. Good condition.",
    lonlat: point(39.2859, -76.5939)
  },
  {
    address: "604 S Broadway",
    owner: "Unknown",
    usage: "Residential",
    notes: "Needs facade work. Contact owner.",
    lonlat: point(39.2871, -76.5940)
  }
])

puts "Created #{Property.count} properties!"