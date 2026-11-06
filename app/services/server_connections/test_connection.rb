module ServerConnections
  class TestConnection
    def initialize(server_connection, client: nil, device_id: nil)
      @server_connection = server_connection
      @client = client
      @device_id = device_id
    end

    def call
      user_name = client.authenticate

      TestConnectionResultData.new(success: true, message: "Connected as #{user_name}.")
    rescue Integrations::AuthenticationError
      TestConnectionResultData.new(success: false, message: "The saved server credentials were rejected.")
    rescue Integrations::ConnectionError => error
      TestConnectionResultData.new(success: false, message: error.message)
    end

    private

    attr_reader :server_connection

    def client
      @client ||= build_client
    end

    def build_client
      Integrations::Client.for(server_connection, device_id: @device_id)
    end
  end
end
