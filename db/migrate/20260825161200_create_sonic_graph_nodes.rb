class CreateSonicGraphNodes < ActiveRecord::Migration[8.0]
  def change
    create_table :sonic_graph_nodes do |t|
      t.references :server_connection, null: false, foreign_key: true
      t.string :item_id, null: false
      t.string :title, null: false
      t.string :artist
      t.string :artwork_url
      t.datetime :synced_at, null: false
      t.timestamps
    end

    add_index :sonic_graph_nodes, [ :server_connection_id, :item_id ], unique: true, name: "idx_sonic_graph_nodes_unique"
  end
end
