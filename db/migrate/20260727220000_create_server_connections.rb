class CreateServerConnections < ActiveRecord::Migration[8.1]
  def change
    create_table :server_connections do |t|
      t.string :name, null: false
      t.string :provider, null: false
      t.string :base_url, null: false
      t.text :username, null: false
      t.text :password, null: false

      t.timestamps
    end

    add_index :server_connections, :name, unique: true
  end
end
