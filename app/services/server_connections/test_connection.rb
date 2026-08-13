module ServerConnections
  class TestConnection
    def initialize(server_connection, client: nil)
      @server_connection = server_connection
      @client = client
    end

    def call
      user_name = client.authenticate

      TestConnectionResultData.new(success: true, message: "Connected as #{user_name}.")
    rescue Integrations::Jellyfin::Client::AuthenticationError
      TestConnectionResultData.new(success: false, message: "The saved server credentials were rejected.")
    rescue Integrations::Jellyfin::Client::ConnectionError => error
      TestConnectionResultData.new(success: false, message: error.message)
    end

    private

    attr_reader :server_connection

    def client
      @client ||= build_client
    end

    def build_client
      Integrations::Client.for(server_connection)
    end
  end
end
