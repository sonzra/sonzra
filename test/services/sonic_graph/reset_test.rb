require "test_helper"

class SonicGraph::ResetTest < ActiveSupport::TestCase
  setup do
    @connection = ServerConnection.create!(
      name: "Library",
      provider: :jellyfin,
      base_url: "https://jellyfin.example.com",
      username: "bruno",
      password: "secret",
      user: users(:one)
    )
    SonicGraphNode.create!(server_connection: @connection, item_id: "track-1", title: "Track", synced_at: Time.current)
    TrackSimilarity.create!(server_connection: @connection, from_item_id: "track-1", to_item_id: "track-2", distance: 0.2, synced_at: Time.current)
  end

  test "deletes only the selected connection's derived graph data" do
    other_connection = ServerConnection.create!(
      name: "Other library",
      provider: :jellyfin,
      base_url: "https://jellyfin-other.example.com",
      username: "bruno",
      password: "secret",
      user: users(:one)
    )
    SonicGraphNode.create!(server_connection: other_connection, item_id: "other-track", title: "Other track", synced_at: Time.current)

    result = SonicGraph::Reset.new(@connection).call

    assert_equal 1, result.nodes_deleted
    assert_equal 1, result.edges_deleted
    assert_empty SonicGraphNode.where(server_connection: @connection)
    assert_empty TrackSimilarity.where(server_connection: @connection)
    assert SonicGraphNode.exists?(server_connection: other_connection, item_id: "other-track")
  end
end
