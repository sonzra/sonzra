module ServerConnections
  class FetchRadioTracks
    def initialize(server_connection, item_id, limit: 12, remote_user_id: nil, client: nil, access_token: nil, device_id: nil)
      @server_connection = server_connection
      @item_id = item_id
      @limit = limit
      @remote_user_id = remote_user_id
      @client = client
      @access_token = access_token
      @device_id = device_id
    end

    def call
      traverser = SonicGraph::Traverser.new(@server_connection)
      items = if traverser.graph_available?(@item_id)
        next_ids = traverser.next_tracks(@item_id, limit: @limit)
        client.recommendation_tracks_by_ids(next_ids)
      else
        []
      end

      if items.empty?
        response = client.instant_mix(@item_id, limit: @limit)
        items = response.items
      end

      FetchRadioTracksResultData.new(items:, access_token: client.instance_variable_get(:@access_token), message: nil)
    rescue Integrations::AuthenticationError, Integrations::ConnectionError => error
      FetchRadioTracksResultData.new(items: [], access_token: nil, message: error.message.presence || "Could not prepare radio tracks.")
    end

    private

    def client
      @client ||= Integrations::Client.for(@server_connection, remote_user_id: @remote_user_id, access_token: @access_token, device_id: @device_id)
    end
  end
end
