# lib/tasks/property_cleanup.rake
namespace :db do
  desc "Keep specific Baltimore address ranges and destroy the rest"
  task clean_properties: :environment do
    puts "Analyzing properties..."

    # Define exact matches (uppercased for case-insensitive comparison)
    exact_addresses_to_keep = [
      "1654 E PRATT ST",
      "1645 E BALTIMORE ST",
      "1701 E BALTIMORE ST"
    ]

    ids_to_keep = []

    Property.find_each do |property|
      # Normalize to uppercase and strip whitespace for clean comparison
      normalized_address = property.address.to_s.strip.upcase

      # 1. Fast-pass check for our exact matches
      if exact_addresses_to_keep.include?(normalized_address)
        ids_to_keep << property.id
        next
      end

      # 2. Check for the South Broadway block range
      match_data = normalized_address.match(/^(\d+)\s+(.+)$/)
      next unless match_data

      number = match_data[1].to_i
      street = match_data[2]

      # Use regex to handle slight data variations (e.g., "S BROADWAY", "S. BROADWAY")
      if street.match?(/S\.?\s+BROADWAY/) && number.between?(4, 435)
        ids_to_keep << property.id
      end
    end

    total_properties = Property.count
    properties_to_delete_count = total_properties - ids_to_keep.size

    # --- DRY RUN & CONFIRMATION ---
    puts "\n" + "=" * 30
    puts "      DRY RUN ANALYSIS      "
    puts "=" * 30
    puts "Total Properties:     #{total_properties}"
    puts "Properties to KEEP:   #{ids_to_keep.size}"
    puts "Properties to DELETE: #{properties_to_delete_count}"
    puts "=" * 30 + "\n"

    if properties_to_delete_count.zero?
      puts "Nothing to delete! Exiting gracefully."
      return
    end

    # Ask for explicit confirmation. 
    # Note: We must use STDIN.gets in a rake task, otherwise 'gets' tries to read from ARGV.
    print "Type 'CONFIRM' to permanently delete these #{properties_to_delete_count} records, or press Enter to abort: "
    confirmation = STDIN.gets.chomp

    unless confirmation == 'CONFIRM'
      puts "\nAborting. No records were deleted. Your data is safe."
      return
    end

    # --- DELETION EXECUTION ---
    puts "\nExecuting deletion..."
    
    properties_to_delete = Property.where.not(id: ids_to_keep)
    
    properties_to_delete.in_batches(of: 1000) do |relation|
      relation.delete_all
      print "."
    end

    puts "\nCleanup complete! Remaining properties in database: #{Property.count}"
  end
end