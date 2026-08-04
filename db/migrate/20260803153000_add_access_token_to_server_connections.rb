class AddAccessTokenToServerConnections < ActiveRecord::Migration[8.1]
  def change
    add_column :server_connections, :access_token, :text
  end
end
