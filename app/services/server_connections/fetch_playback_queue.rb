module ServerConnections
  class FetchPlaybackQueue
    def initialize(server_connection, item_id, client: nil, access_token: nil, device_id: nil)
      @server_connection = server_connection
      @item_id = item_id
      @client = client
      @access_token = access_token
      @device_id = device_id
    end

    def call
      response = client.playback_queue(@item_id)
      FetchPlaybackQueueResultData.new(items: response.items, access_token: response.access_token, message: nil)
    rescue Integrations::Jellyfin::Client::AuthenticationError, Integrations::Jellyfin::Client::ConnectionError => error
      FetchPlaybackQueueResultData.new(items: [], access_token: nil, message: error.message.presence || "Could not prepare playback.")
    end

    private

    def client
      @client ||= Integrations::Client.for(@server_connection, access_token: @access_token, device_id: @device_id)
    end
  end
end
