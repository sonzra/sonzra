module ServerConnections
  class FetchPlaybackQueue
    def initialize(server_connection, item_id, client: nil)
      @server_connection = server_connection
      @item_id = item_id
      @client = client
    end

    def call
      response = client.playback_queue(@item_id)
      FetchPlaybackQueueResultData.new(items: response.items, access_token: response.access_token, message: nil)
    rescue Integrations::Jellyfin::Client::AuthenticationError, Integrations::Jellyfin::Client::ConnectionError => error
      FetchPlaybackQueueResultData.new(items: [], access_token: nil, message: error.message.presence || "Could not prepare playback.")
    end

    private

    def client
      @client ||= Integrations::Jellyfin::Client.new(base_url: @server_connection.base_url, username: @server_connection.username, password: @server_connection.password)
    end
  end
end
