module ServerConnections
  class FetchLibraryCollection
    def initialize(server_connection, collection, user: nil, page: 1, query: nil, genre: nil, letter: nil, client: nil)
      @server_connection = server_connection
      @collection = collection
      @user = user
      @page = page
      @query = query
      @genre = genre
      @letter = letter
      @client = client
    end

    def call
      response = client.library_collection(@collection, page: @page, query: @query, genre: @genre, letter: @letter)
      items = @user ? HiddenArtists::Filter.new(@user, @server_connection).items(response.content) : response.content
      has_more = (@page * Library::Pagination::PAGE_SIZE) < response.total
      FetchLibraryCollectionResultData.new(items:, total: response.total, access_token: response.access_token, message: nil, has_more:)
    rescue Integrations::Jellyfin::Client::AuthenticationError, Integrations::Jellyfin::Client::ConnectionError => error
      FetchLibraryCollectionResultData.new(items: [], total: 0, access_token: nil, message: error.message.presence || "Could not load this library.", has_more: false)
    end

    def supports?(capability)
      client.respond_to?(:supports?) && client.supports?(capability)
    end

    private

    def client
      @client ||= Integrations::Client.for(@server_connection)
    end
  end
end
