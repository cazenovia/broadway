class CreateProperties < ActiveRecord::Migration[8.0]
  def change
    enable_extension 'postgis'

    create_table :properties do |t|
      t.string :address
      t.string :owner
      t.string :usage_type # (Remembering your fix!)
      t.text :notes
      
      # CHANGED: We now use a generic geometry column to hold Polygons
      t.geometry :boundary, geographic: true 

      t.timestamps
    end
    
    add_index :properties, :boundary, using: :gist
  end
end