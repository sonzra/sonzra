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

ActiveRecord::Schema[8.1].define(version: 2026_08_25_161200) do
  create_table "application_settings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "registrations_enabled", default: true, null: false
    t.datetime "updated_at", null: false
  end

  create_table "hidden_artists", force: :cascade do |t|
    t.string "artist_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.integer "server_connection_id", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["server_connection_id"], name: "index_hidden_artists_on_server_connection_id"
    t.index ["user_id", "server_connection_id", "artist_id"], name: "index_hidden_artists_on_connection_and_artist", unique: true
    t.index ["user_id"], name: "index_hidden_artists_on_user_id"
  end

  create_table "listening_events", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "item_id", null: false
    t.datetime "occurred_at", null: false
    t.integer "server_connection_id", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["server_connection_id"], name: "index_listening_events_on_server_connection_id"
    t.index ["user_id", "item_id", "occurred_at"], name: "index_listening_events_on_user_id_and_item_id_and_occurred_at"
    t.index ["user_id", "occurred_at"], name: "index_listening_events_on_user_id_and_occurred_at"
    t.index ["user_id"], name: "index_listening_events_on_user_id"
  end

  create_table "media_servers", force: :cascade do |t|
    t.string "base_url", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "provider", null: false
    t.datetime "updated_at", null: false
    t.index ["provider", "base_url"], name: "index_media_servers_on_provider_and_base_url", unique: true
  end

  create_table "recommendation_collection_events", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "event_type", null: false
    t.datetime "occurred_at", null: false
    t.integer "recommendation_collection_id", null: false
    t.datetime "updated_at", null: false
    t.index ["recommendation_collection_id", "event_type"], name: "index_recommendation_events_on_collection_and_type"
    t.index ["recommendation_collection_id"], name: "idx_on_recommendation_collection_id_006bbe3fb8"
  end

  create_table "recommendation_collections", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "generated_at", null: false
    t.date "period_date", null: false
    t.integer "server_connection_id", null: false
    t.string "strategy", null: false
    t.string "subtitle", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["server_connection_id"], name: "index_recommendation_collections_on_server_connection_id"
    t.index ["user_id", "server_connection_id", "strategy", "period_date"], name: "index_recommendations_on_user_connection_strategy_period", unique: true
    t.index ["user_id"], name: "index_recommendation_collections_on_user_id"
  end

  create_table "recommendation_runs", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "error_message"
    t.datetime "generated_at"
    t.date "period_date", null: false
    t.integer "recommendation_collection_id"
    t.integer "server_connection_id"
    t.string "status", default: "pending", null: false
    t.string "strategy", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["recommendation_collection_id"], name: "index_recommendation_runs_on_recommendation_collection_id"
    t.index ["server_connection_id"], name: "index_recommendation_runs_on_server_connection_id"
    t.index ["user_id", "server_connection_id", "strategy", "period_date"], name: "index_recommendation_runs_on_user_connection_strategy_period", unique: true
    t.index ["user_id"], name: "index_recommendation_runs_on_user_id"
  end

  create_table "recommendation_tracks", force: :cascade do |t|
    t.string "album"
    t.string "album_artist"
    t.string "album_id"
    t.string "artist"
    t.string "artist_id"
    t.string "artwork_item_id"
    t.datetime "created_at", null: false
    t.string "duration"
    t.string "genre"
    t.string "item_id", null: false
    t.integer "position", null: false
    t.integer "recommendation_collection_id", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["recommendation_collection_id", "position"], name: "index_recommendation_tracks_on_collection_position", unique: true
    t.index ["recommendation_collection_id"], name: "index_recommendation_tracks_on_recommendation_collection_id"
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

  create_table "sonic_graph_nodes", force: :cascade do |t|
    t.string "artist"
    t.string "artwork_url"
    t.datetime "created_at", null: false
    t.string "item_id", null: false
    t.integer "server_connection_id", null: false
    t.datetime "synced_at", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["server_connection_id", "item_id"], name: "idx_sonic_graph_nodes_unique", unique: true
    t.index ["server_connection_id"], name: "index_sonic_graph_nodes_on_server_connection_id"
  end

  create_table "track_similarities", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.float "distance", default: 1.0, null: false
    t.string "from_item_id", null: false
    t.integer "server_connection_id", null: false
    t.datetime "synced_at", null: false
    t.string "to_item_id", null: false
    t.datetime "updated_at", null: false
    t.index ["server_connection_id", "from_item_id", "to_item_id"], name: "idx_track_similarities_unique", unique: true
    t.index ["server_connection_id", "from_item_id"], name: "idx_track_similarities_connection_from"
    t.index ["server_connection_id"], name: "index_track_similarities_on_server_connection_id"
  end

  create_table "tv_device_sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.datetime "last_used_at"
    t.string "token_digest", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["token_digest"], name: "index_tv_device_sessions_on_token_digest", unique: true
    t.index ["user_id"], name: "index_tv_device_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.boolean "admin", default: false, null: false
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.integer "preferred_server_connection_id"
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.index ["preferred_server_connection_id"], name: "index_users_on_preferred_server_connection_id"
  end

  add_foreign_key "hidden_artists", "server_connections"
  add_foreign_key "hidden_artists", "users"
  add_foreign_key "listening_events", "server_connections"
  add_foreign_key "listening_events", "users"
  add_foreign_key "recommendation_collection_events", "recommendation_collections"
  add_foreign_key "recommendation_collections", "server_connections"
  add_foreign_key "recommendation_collections", "users"
  add_foreign_key "recommendation_runs", "recommendation_collections"
  add_foreign_key "recommendation_runs", "server_connections"
  add_foreign_key "recommendation_runs", "users"
  add_foreign_key "recommendation_tracks", "recommendation_collections"
  add_foreign_key "server_connections", "media_servers"
  add_foreign_key "server_connections", "users"
  add_foreign_key "sessions", "users"
  add_foreign_key "sonic_graph_nodes", "server_connections"
  add_foreign_key "track_similarities", "server_connections"
  add_foreign_key "tv_device_sessions", "users"
  add_foreign_key "users", "server_connections", column: "preferred_server_connection_id"
end
