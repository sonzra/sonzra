require "test_helper"

class SonicGraph::TraverserTest < ActiveSupport::TestCase
  setup do
    @connection = ServerConnection.create!(
      name: "Library",
      provider: :jellyfin,
      base_url: "https://jellyfin.example.com",
      username: "bruno",
      password: "secret",
      user: users(:one)
    )
    TrackSimilarity.create!(server_connection: @connection, from_item_id: "track-1", to_item_id: "track-2", distance: 0.2, synced_at: Time.current)
    TrackSimilarity.create!(server_connection: @connection, from_item_id: "track-1", to_item_id: "track-3", distance: 0.5, synced_at: Time.current)
    TrackSimilarity.create!(server_connection: @connection, from_item_id: "track-1", to_item_id: "track-4", distance: 0.8, synced_at: Time.current)
  end

  test "returns next tracks excluding history" do
    traverser = SonicGraph::Traverser.new(@connection)

    next_tracks = traverser.next_tracks("track-1", limit: 2, history_item_ids: [ "track-2" ])
    assert_equal [ "track-3", "track-4" ], next_tracks
  end

  test "checks graph availability for a seed track" do
    traverser = SonicGraph::Traverser.new(@connection)

    assert traverser.graph_available?("track-1")
    assert_not traverser.graph_available?("unknown-track")
  end
end
