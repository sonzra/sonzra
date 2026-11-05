module Library
  class TabCounts
    COLLECTIONS = %i[albums artists playlists podcasts audiobooks genres].freeze

    def initialize(server_connection, user:, access_token: nil, device_id: nil)
      @server_connection = server_connection
      @user = user
      @access_token = access_token
      @device_id = device_id
    end

    def call
      Rails.cache.fetch(cache_key, expires_in: 5.minutes) do
        options = {}
        options[:access_token] = @access_token if @access_token.present?
        options[:device_id] = @device_id if @device_id.present?
        client = options.any? ? Integrations::Client.for(@server_connection, **options) : Integrations::Client.for(@server_connection)
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
