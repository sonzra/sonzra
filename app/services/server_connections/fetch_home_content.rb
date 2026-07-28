module ServerConnections
  class FetchHomeContent
    def initialize(server_connection, client: nil)
      @server_connection = server_connection
      @client = client
    end

    def call
      response = client.home_content
      FetchHomeContentResultData.new(content: response.content, access_token: response.access_token, message: nil)
    rescue Integrations::Jellyfin::Client::AuthenticationError
      FetchHomeContentResultData.new(content: nil, access_token: nil, message: "The saved server credentials were rejected.")
    rescue Integrations::Jellyfin::Client::ConnectionError => error
      FetchHomeContentResultData.new(content: nil, access_token: nil, message: error.message)
    end

    private

    def client
      @client ||= Integrations::Jellyfin::Client.new(
        base_url: @server_connection.base_url,
        username: @server_connection.username,
        password: @server_connection.password
      )
    end
  end
end
