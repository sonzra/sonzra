class AddRemoteUserIdToServerConnections < ActiveRecord::Migration[8.1]
  def change
    add_column :server_connections, :remote_user_id, :string
    add_index :server_connections, :remote_user_id
  end
end
