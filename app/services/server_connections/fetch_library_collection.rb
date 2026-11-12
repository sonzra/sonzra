module ServerConnections
  class FetchLibraryCollection
    def initialize(server_connection, collection, user: nil, page: 1, query: nil, genre: nil, letter: nil, client: nil, access_token: nil, device_id: nil)
      @server_connection = server_connection
      @collection = collection
      @user = user
      @page = page
      @query = query
      @genre = genre
      @letter = letter
      @client = client
      @access_token = access_token
      @device_id = device_id
    end

    def call
      response = client.library_collection(@collection, page: @page, query: @query, genre: @genre, letter: @letter)
      items = response.content
      if @user
        items = HiddenArtists::Filter.new(@user, @server_connection).items(items)
        items = HiddenGenres::Filter.new(@user, @server_connection).items(items)
      end
      if @collection == :playlists && supports?(Integrations::Capabilities::COLLABORATIVE_PLAYLISTS)
        items = enrich_playlists_collaboration_status(items)
      end
      has_more = (@page * Library::Pagination::PAGE_SIZE) < response.total
      FetchLibraryCollectionResultData.new(items:, total: response.total, access_token: response.access_token, message: nil, has_more:)
    rescue Integrations::AuthenticationError, Integrations::ConnectionError => error
      FetchLibraryCollectionResultData.new(items: [], total: 0, access_token: nil, message: error.message.presence || "Could not load this library.", has_more: false)
    end

    def supports?(capability)
      client.respond_to?(:supports?) && client.supports?(capability)
    end

    private

    def client
      @client ||= Integrations::Client.for(@server_connection, access_token: @access_token, device_id: @device_id)
    end

    def enrich_playlists_collaboration_status(items)
      return items if items.empty?

      if Rails.env.test? || items.size <= 1
        items.map do |item|
          item_copy = item.dup
          enrich_single_playlist(item_copy)
          item_copy
        end
      else
        threads = items.map do |item|
          Thread.new do
            item_copy = item.dup
            enrich_single_playlist(item_copy)
            item_copy
          end
        end
        threads.map(&:value)
      end
    end

    def enrich_single_playlist(item)
      users_result = ServerConnections::CollaborativePlaylists::FetchPlaylistUsers.new(
        @server_connection,
        playlist_id: item["Id"],
        client: client
      ).call

      if users_result.success?
        item["IsOwner"] = true
        collaborators = (users_result.users || []).reject do |u|
          (u["UserId"] || u["Id"]) == @server_connection.remote_user_id
        end
        if collaborators.any?
          item["CollaborationStatus"] = :collaborative
          item["IsSharedWithOthers"] = true
          item["CanDelete"] = false
        else
          item["CollaborationStatus"] = :owned
          item["IsSharedWithOthers"] = false
          item["CanDelete"] = true
        end
      else
        item["IsOwner"] = false
        item["CollaborationStatus"] = :shared_with_me
        item["IsSharedWithOthers"] = false
        item["CanDelete"] = false
      end
    rescue StandardError
      item["IsOwner"] = false
      item["CollaborationStatus"] = :shared_with_me
      item["IsSharedWithOthers"] = false
      item["CanDelete"] = false
    end
  end
end
