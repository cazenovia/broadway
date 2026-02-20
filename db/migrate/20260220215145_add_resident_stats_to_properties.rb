class AddResidentStatsToProperties < ActiveRecord::Migration[8.1]
  def change
    add_column :properties, :residential_units, :integer
    add_column :properties, :estimated_residents, :integer
  end
end
