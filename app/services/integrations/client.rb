module Integrations
  class Client
    def self.for(server_connection, **options)
      case server_connection.provider.to_sym
      when :jellyfin then Jellyfin::Client.new(**server_connection.client_options(**options))
      when :plex then Plex::Client.new(**server_connection.client_options(**options))
      else raise ArgumentError, "Unsupported media provider: #{server_connection.provider}"
      end
    end
  end
end
