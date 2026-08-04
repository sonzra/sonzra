class RemoveRemoteUserIdFromServerConnections < ActiveRecord::Migration[8.1]
  def change
    remove_column :server_connections, :remote_user_id, :string
  end
end
