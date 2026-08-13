module ServerConnections
  class FetchCachedHomeContent
    CACHE_TTL = 5.minutes
    CACHE_VERSION = 8

    def self.invalidate(server_connection, cache: Rails.cache)
      cache.delete([ "server_connection", server_connection.cache_key_with_version, "home_content", CACHE_VERSION ])
    end

    def initialize(server_connection, access_token:, user: nil, fetch_home_content: nil, cache: Rails.cache)
      @server_connection = server_connection
      @access_token = access_token
      @user = user
      @fetch_home_content = fetch_home_content
      @cache = cache
    end

    def call
      cached_content = cache.read(cache_key)
      return filter_result(cached_result(cached_content)) if cached_content && access_token.present?

      result = fetch_home_content.call
      cache.write(cache_key, result.content, expires_in: CACHE_TTL) if result.success?
      filter_result(result)
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

    def filter_result(result)
      return result unless result.success? && @user

      filter = HiddenArtists::Filter.new(@user, server_connection)
      content = result.content.transform_values { |value| value.is_a?(Array) ? filter.items(value) : value }
      FetchHomeContentResultData.new(content:, access_token: result.access_token, message: result.message)
    end
  end
end
