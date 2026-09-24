module Library
  class TabCounts
    COLLECTIONS = %i[albums artists playlists podcasts audiobooks genres].freeze

    def initialize(server_connection, user:)
      @server_connection = server_connection
      @user = user
    end

    def call
      Rails.cache.fetch(cache_key, expires_in: 5.minutes) do
        client = Integrations::Client.for(@server_connection)
        COLLECTIONS.to_h do |collection|
          result = ServerConnections::FetchLibraryCollection.new(@server_connection, collection, user: @user, client:).call
          [ collection, result.success? ? result.total : nil ]
        end
      end
    end

    private

    def cache_key
      [ "library-tab-counts", @server_connection.cache_key_with_version, @user.cache_key_with_version ]
    end
  end
end
