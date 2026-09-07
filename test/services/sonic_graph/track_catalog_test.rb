require "test_helper"

class SonicGraph::TrackCatalogTest < ActiveSupport::TestCase
  setup do
    @server_connection = ServerConnection.create!(
      name: "Test Connection",
      provider: :jellyfin,
      base_url: "https://jellyfin.example.com",
      username: "bruno",
      password: "secret",
      user: users(:one)
    )
    @cache = ActiveSupport::Cache::MemoryStore.new
    @original_cache = Rails.cache
    Rails.cache = @cache
  end

  teardown do
    Rails.cache = @original_cache
  end

  test "reuses a connection-scoped catalog instead of re-fetching Jellyfin" do
    client = Object.new
    calls = 0
    client.define_singleton_method(:all_track_ids) do
      calls += 1
      [ "track-1", "track-2" ]
    end

    catalog = SonicGraph::TrackCatalog.new(server_connection: @server_connection, client:)

    assert_equal [ "track-1", "track-2" ], catalog.track_ids
    assert_equal [ "track-1", "track-2" ], catalog.track_ids
    assert_equal 1, calls
  end

  test "does not cache an empty response so a temporary Jellyfin failure can recover" do
    client = Object.new
    responses = [ [], [ "track-1" ] ]
    client.define_singleton_method(:all_track_ids) { responses.shift }

    catalog = SonicGraph::TrackCatalog.new(server_connection: @server_connection, client:)

    assert_equal [], catalog.track_ids
    assert_equal [ "track-1" ], catalog.track_ids
  end
end
