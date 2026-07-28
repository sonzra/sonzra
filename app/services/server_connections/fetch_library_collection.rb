module ServerConnections
  class FetchLibraryCollection
    def initialize(server_connection, collection, page: 1, query: nil, genre: nil, client: nil)
      @server_connection = server_connection
      @collection = collection
      @page = page
      @query = query
      @genre = genre
      @client = client
    end

    def call
      response = client.library_collection(@collection, page: @page, query: @query, genre: @genre)
      FetchLibraryCollectionResultData.new(items: response.content, total: response.total, access_token: response.access_token, message: nil)
    rescue Integrations::Jellyfin::Client::AuthenticationError, Integrations::Jellyfin::Client::ConnectionError => error
      FetchLibraryCollectionResultData.new(items: [], total: 0, access_token: nil, message: error.message.presence || "Could not load this library.")
    end

    private

    def client
      @client ||= Integrations::Jellyfin::Client.new(base_url: @server_connection.base_url, username: @server_connection.username, password: @server_connection.password)
    end
  end
end
