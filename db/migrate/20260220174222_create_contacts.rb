class CreateContacts < ActiveRecord::Migration[8.1]
  def change
    create_table :contacts do |t|
      t.references :property, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.date :contact_date
      t.string :contact_person
      t.string :contact_person_role
      t.string :contact_method
      t.text :contact_summary

      t.timestamps
    end
  end
end
