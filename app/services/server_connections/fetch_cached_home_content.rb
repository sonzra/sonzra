module ServerConnections
  class FetchCachedHomeContent
    CACHE_TTL = 5.minutes
    CACHE_VERSION = 4

    def initialize(server_connection, access_token:, fetch_home_content: nil, cache: Rails.cache)
      @server_connection = server_connection
      @access_token = access_token
      @fetch_home_content = fetch_home_content
      @cache = cache
    end

    def call
      cached_content = cache.read(cache_key)
      return cached_result(cached_content) if cached_content && access_token.present?

      result = fetch_home_content.call
      cache.write(cache_key, result.content, expires_in: CACHE_TTL) if result.success?
      result
    end

    private

    attr_reader :server_connection, :access_token, :cache

    def cache_key
      [ "server_connection", server_connection.cache_key_with_version, "home_content", CACHE_VERSION ]
    end

    def cached_result(content)
      FetchHomeContentResultData.new(content: content, access_token: access_token, message: nil)
    end

    def fetch_home_content
      @fetch_home_content ||= FetchHomeContent.new(server_connection)
    end
  end
end
