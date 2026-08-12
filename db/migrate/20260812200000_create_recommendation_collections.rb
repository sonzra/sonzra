class CreateRecommendationCollections < ActiveRecord::Migration[8.1]
  def change
    create_table :recommendation_collections do |t|
      t.references :user, null: false, foreign_key: true
      t.references :server_connection, null: false, foreign_key: true
      t.string :strategy, null: false
      t.date :period_date, null: false
      t.string :title, null: false
      t.string :subtitle, null: false
      t.datetime :generated_at, null: false
      t.timestamps
    end
    add_index :recommendation_collections, %i[user_id strategy period_date], unique: true, name: "index_recommendations_on_user_strategy_period"

    create_table :recommendation_tracks do |t|
      t.references :recommendation_collection, null: false, foreign_key: true
      t.string :item_id, null: false
      t.integer :position, null: false
      t.string :title, null: false
      t.string :artist
      t.string :album
      t.string :album_artist
      t.string :album_id
      t.string :artwork_item_id
      t.string :duration
      t.string :genre
      t.timestamps
    end
    add_index :recommendation_tracks, %i[recommendation_collection_id position], unique: true, name: "index_recommendation_tracks_on_collection_position"

    create_table :recommendation_runs do |t|
      t.references :user, null: false, foreign_key: true
      t.references :recommendation_collection, foreign_key: true
      t.string :strategy, null: false
      t.date :period_date, null: false
      t.string :status, null: false, default: "pending"
      t.datetime :generated_at
      t.text :error_message
      t.timestamps
    end
    add_index :recommendation_runs, %i[user_id strategy period_date], unique: true, name: "index_recommendation_runs_on_user_strategy_period"

  end
end
