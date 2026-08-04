class AllowTokenOnlyServerConnections < ActiveRecord::Migration[8.1]
  def change
    change_column_null :server_connections, :password, true
  end
end
