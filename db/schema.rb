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

ActiveRecord::Schema[8.1].define(version: 2026_08_03_220500) do
  create_table "application_settings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "registrations_enabled", default: true, null: false
    t.datetime "updated_at", null: false
  end

  create_table "media_servers", force: :cascade do |t|
    t.string "base_url", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "provider", null: false
    t.datetime "updated_at", null: false
    t.index ["provider", "base_url"], name: "index_media_servers_on_provider_and_base_url", unique: true
  end

  create_table "server_connections", force: :cascade do |t|
    t.text "access_token"
    t.datetime "created_at", null: false
    t.integer "media_server_id", null: false
    t.text "password"
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.text "username", null: false
    t.index ["media_server_id"], name: "index_server_connections_on_media_server_id"
    t.index ["user_id", "media_server_id"], name: "index_server_connections_on_user_id_and_media_server_id", unique: true
    t.index ["user_id"], name: "index_server_connections_on_user_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.boolean "admin", default: false, null: false
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "server_connections", "media_servers"
  add_foreign_key "server_connections", "users"
  add_foreign_key "sessions", "users"
end
