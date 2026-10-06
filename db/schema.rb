# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_10_06_135719) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "events", force: :cascade do |t|
    t.string "billetto_id"
    t.string "title"
    t.text "description"
    t.string "image_url"
    t.string "event_url"
    t.datetime "starts_at"
    t.datetime "ends_at"
    t.string "organiser_name"
    t.string "location_name"
    t.string "address"
    t.string "city"
    t.string "postal_code"
    t.string "country"
    t.string "country_code"
    t.string "category"
    t.string "subcategory"
    t.boolean "available"
    t.text "raw_data"
    t.datetime "last_synced_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["billetto_id"], name: "index_events_on_billetto_id", unique: true
    t.index ["starts_at"], name: "index_events_on_starts_at"
  end
end
