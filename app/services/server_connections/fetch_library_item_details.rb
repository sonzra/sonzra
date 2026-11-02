module ServerConnections
  class FetchLibraryItemDetails
    def initialize(server_connection, item_id, user: nil, client: nil)
      @server_connection = server_connection
      @item_id = item_id
      @user = user
      @client = client
    end

    def call
      response = client.library_item_details(@item_id)
      details = filtered_details(response.details)
      return FetchLibraryItemDetailsResultData.new(details: nil, access_token: response.access_token, message: "This artist is hidden.") unless details

      FetchLibraryItemDetailsResultData.new(details:, access_token: response.access_token, message: nil)
    rescue Integrations::Jellyfin::Client::AuthenticationError, Integrations::Jellyfin::Client::ConnectionError => error
      FetchLibraryItemDetailsResultData.new(details: nil, access_token: nil, message: error.message.presence || "Could not load this item.")
    end

    private

    def client
      @client ||= Integrations::Client.for(@server_connection)
    end

    def filtered_details(details)
      return details unless @user

      artist_filter = HiddenArtists::Filter.new(@user, @server_connection)
      genre_filter = HiddenGenres::Filter.new(@user, @server_connection)
      return nil if artist_filter.hidden?(details[:item]) || genre_filter.hidden?(details[:item])

      details.merge(
        tracks: genre_filter.items(artist_filter.items(details.fetch(:tracks, []))),
        other_albums: genre_filter.items(artist_filter.items(details.fetch(:other_albums, []))),
        similar_albums: genre_filter.items(artist_filter.items(details.fetch(:similar_albums, [])))
      )
    end
  end
end
