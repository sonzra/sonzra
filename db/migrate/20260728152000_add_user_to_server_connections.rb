class AddUserToServerConnections < ActiveRecord::Migration[8.1]
  def change
    add_reference :server_connections, :user, foreign_key: true
    remove_index :server_connections, :name
    add_index :server_connections, [ :user_id, :name ], unique: true
  end
end
