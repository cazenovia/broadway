Property.destroy_all

puts "Seeding South Broadway with Real Boundaries..."

Property.create!([
  {
    address: "500 S Broadway",
    usage_type: "Public",
    notes: "Old market building, potential for mixed use.",
    # A real rectangular footprint on the corner
    boundary: "POLYGON((-76.59398 39.28565, -76.59365 39.28565, -76.59365 39.28515, -76.59398 39.28515, -76.59398 39.28565))"
  },
  {
    address: "512 S Broadway",
    usage_type: "Retail",
    notes: "Currently a vacant storefront. Good condition.",
    # A narrow rowhouse-style footprint
    boundary: "POLYGON((-76.59400 39.28590, -76.59370 39.28590, -76.59370 39.28570, -76.59400 39.28570, -76.59400 39.28590))"
  },
  {
    address: "604 S Broadway",
    usage_type: "Residential",
    notes: "Needs facade work. Contact owner.",
    boundary: "POLYGON((-76.59410 39.28715, -76.59380 39.28715, -76.59380 39.28695, -76.59410 39.28695, -76.59410 39.28715))"
  }
])

puts "Created #{Property.count} properties with polygons!"