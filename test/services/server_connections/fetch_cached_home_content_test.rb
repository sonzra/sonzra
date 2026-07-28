require "test_helper"

class ServerConnections::FetchCachedHomeContentTest < ActiveSupport::TestCase
  setup do
    @server_connection = ServerConnection.new(
      name: "Home",
      provider: :jellyfin,
      base_url: "https://example.com",
      username: "bruno",
      password: "secret"
    )
    @server_connection.define_singleton_method(:cache_key_with_version) { "server_connections/1-20260728000000" }
    @cache = ActiveSupport::Cache::MemoryStore.new
  end

  test "uses cached home content when the session has an access token" do
    @cache.write(cache_key, { recently_played: [ { "Name" => "Cached song" } ] })
    fetcher = Object.new
    fetcher.define_singleton_method(:call) { flunk "Jellyfin should not be called" }

    result = ServerConnections::FetchCachedHomeContent.new(
      @server_connection,
      access_token: "session-token",
      fetch_home_content: fetcher,
      cache: @cache
    ).call

    assert result.success?
    assert_equal "Cached song", result.content[:recently_played].first["Name"]
    assert_equal "session-token", result.access_token
  end

  test "fetches and caches home content when there is no session token" do
    fetched_result = ServerConnections::FetchHomeContentResultData.new(
      content: { recently_played: [ { "Name" => "Fresh song" } ] },
      access_token: "fresh-token",
      message: nil
    )
    fetcher = Object.new
    fetcher.define_singleton_method(:call) { fetched_result }

    result = ServerConnections::FetchCachedHomeContent.new(
      @server_connection,
      access_token: nil,
      fetch_home_content: fetcher,
      cache: @cache
    ).call

    assert_equal fetched_result, result
    assert_equal fetched_result.content, @cache.read(cache_key)
  end

  private

  def cache_key
    [ "server_connection", @server_connection.cache_key_with_version, "home_content", ServerConnections::FetchCachedHomeContent::CACHE_VERSION ]
  end
end
