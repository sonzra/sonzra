class CreateHiddenGenres < ActiveRecord::Migration[8.1]
  def change
    create_table :hidden_genres do |t|
      t.references :user, null: false, foreign_key: true
      t.references :server_connection, null: false, foreign_key: true
      t.string :name, null: false

      t.timestamps
    end

    add_index :hidden_genres, %i[user_id server_connection_id name], unique: true, name: "index_hidden_genres_on_connection_and_name"
  end
end
