class CreateProperties < ActiveRecord::Migration[8.0]
  def change
    enable_extension 'postgis'

    create_table :properties do |t|
      t.string :address
      t.string :owner_name
      t.string :usage_type
      t.text :notes
      
      t.st_point :lonlat, geographic: true

      t.timestamps
    end
    
    add_index :properties, :lonlat, using: :gist
  end
end