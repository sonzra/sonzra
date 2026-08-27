class CreateTrackSimilarities < ActiveRecord::Migration[8.0]
  def change
    create_table :track_similarities do |t|
      t.references :server_connection, null: false, foreign_key: true
      t.string :from_item_id, null: false
      t.string :to_item_id, null: false
      t.float :distance, null: false, default: 1.0
      t.datetime :synced_at, null: false

      t.timestamps
    end

    add_index :track_similarities, [ :server_connection_id, :from_item_id ], name: "idx_track_similarities_connection_from"
    add_index :track_similarities, [ :server_connection_id, :from_item_id, :to_item_id ], unique: true, name: "idx_track_similarities_unique"
  end
end
