class AddDetailsToProperties < ActiveRecord::Migration[8.1]
  def change
    add_column :properties, :year_built, :integer
    add_column :properties, :sale_price, :integer
    add_column :properties, :sale_date, :datetime
  end
end
