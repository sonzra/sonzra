module ServerConnections
  class FetchLibraryItemDetails
    def initialize(server_connection, item_id, client: nil)
      @server_connection = server_connection
      @item_id = item_id
      @client = client
    end

    def call
      response = client.library_item_details(@item_id)
      FetchLibraryItemDetailsResultData.new(details: response.details, access_token: response.access_token, message: nil)
    rescue Integrations::Jellyfin::Client::AuthenticationError, Integrations::Jellyfin::Client::ConnectionError => error
      FetchLibraryItemDetailsResultData.new(details: nil, access_token: nil, message: error.message.presence || "Could not load this item.")
    end

    private

    def client
      @client ||= Integrations::Jellyfin::Client.new(base_url: @server_connection.base_url, username: @server_connection.username, password: @server_connection.password)
    end
  end
end
