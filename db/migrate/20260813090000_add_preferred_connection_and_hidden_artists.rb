class AddPreferredConnectionAndHiddenArtists < ActiveRecord::Migration[8.1]
  def change
    add_reference :users, :preferred_server_connection, foreign_key: { to_table: :server_connections }

    create_table :hidden_artists do |t|
      t.references :user, null: false, foreign_key: true
      t.references :server_connection, null: false, foreign_key: true
      t.string :artist_id, null: false
      t.string :name, null: false
      t.timestamps
    end
    add_index :hidden_artists, %i[user_id server_connection_id artist_id], unique: true, name: "index_hidden_artists_on_connection_and_artist"

    add_column :recommendation_tracks, :artist_id, :string
  end
end
