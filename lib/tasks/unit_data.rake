# lib/tasks/property_data.rake
namespace :properties do
  desc "Queue jobs to fetch multi-family unit data from Baltimore ArcGIS"
  task fetch_all_units: :environment do
    # Only target properties that don't already have unit data
    # to save API calls and processing time.
    target_properties = Property.where(residential_units: nil)
    
    total_count = target_properties.count
    
    if total_count.zero?
      puts "All properties already have unit data. Nothing to queue!"
      return
    end

    puts "Queueing #{total_count} jobs to fetch property units..."

    # find_each loads records in batches (default 1000) to save memory
    target_properties.find_each do |property|
      # perform_later pushes the ID to your job queue (Solid Queue / Sidekiq / etc.)
      FetchPropertyUnitsJob.perform_later(property.id)
      print "."
    end

    puts "\nDone! #{total_count} jobs have been added to the queue."
  end
end