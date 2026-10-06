class CreateEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :events do |t|
      t.string :billetto_id
      t.string :title
      t.text :description
      t.string :image_url
      t.string :event_url
      t.datetime :starts_at
      t.datetime :ends_at
      t.string :organiser_name
      t.string :location_name
      t.string :address
      t.string :city
      t.string :postal_code
      t.string :country
      t.string :country_code
      t.string :category
      t.string :subcategory
      t.boolean :available
      t.text :raw_data
      t.datetime :last_synced_at

      t.timestamps
    end

    add_index :events, :billetto_id, unique: true
    add_index :events, :starts_at
  end
end
