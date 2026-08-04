class CreateMediaServers < ActiveRecord::Migration[8.1]
  class LegacyServerConnection < ActiveRecord::Base
    self.table_name = "server_connections"
  end

  def up
    create_table :media_servers do |t|
      t.string :name, null: false
      t.string :provider, null: false
      t.string :base_url, null: false
      t.timestamps
    end
    add_index :media_servers, [ :provider, :base_url ], unique: true

    add_reference :server_connections, :media_server, foreign_key: true

    LegacyServerConnection.reset_column_information
    LegacyServerConnection.where(media_server_id: nil).find_each do |connection|
      server = MediaServerRecord.find_or_create_by!(provider: connection.provider, base_url: connection.base_url) do |record|
        record.name = connection.name
      end
      connection.update_columns(media_server_id: server.id)
    end

    change_column_null :server_connections, :media_server_id, false
    remove_index :server_connections, name: "index_server_connections_on_user_id_and_name"
    remove_column :server_connections, :name
    remove_column :server_connections, :provider
    remove_column :server_connections, :base_url
    add_index :server_connections, [ :user_id, :media_server_id ], unique: true
  end

  def down
    remove_index :server_connections, column: [ :user_id, :media_server_id ]
    add_column :server_connections, :name, :string
    add_column :server_connections, :provider, :string
    add_column :server_connections, :base_url, :string

    LegacyServerConnection.reset_column_information
    LegacyServerConnection.find_each do |connection|
      server = MediaServerRecord.find(connection.media_server_id)
      connection.update_columns(name: server.name, provider: server.provider, base_url: server.base_url)
    end

    change_column_null :server_connections, :name, false
    change_column_null :server_connections, :provider, false
    change_column_null :server_connections, :base_url, false
    add_index :server_connections, [ :user_id, :name ], unique: true
    remove_reference :server_connections, :media_server, foreign_key: true
    drop_table :media_servers
  end

  class MediaServerRecord < ActiveRecord::Base
    self.table_name = "media_servers"
  end
end
