require "test_helper"

class TrackSimilarityTest < ActiveSupport::TestCase
  setup do
    @connection = ServerConnection.create!(
      name: "Jellyfin Server",
      provider: :jellyfin,
      base_url: "https://jellyfin.example.com",
      username: "bruno",
      password: "secret",
      user: users(:one)
    )
  end

  test "returns ordered neighbors for a track and connection" do
    TrackSimilarity.create!(server_connection: @connection, from_item_id: "track-1", to_item_id: "track-2", distance: 0.8, synced_at: Time.current)
    TrackSimilarity.create!(server_connection: @connection, from_item_id: "track-1", to_item_id: "track-3", distance: 0.2, synced_at: Time.current)

    neighbors = TrackSimilarity.neighbors_for(@connection, "track-1")
    assert_equal [ "track-3", "track-2" ], neighbors.map(&:to_item_id)
  end

  test "prunes incoming and outgoing similarity edges for a track" do
    TrackSimilarity.create!(server_connection: @connection, from_item_id: "track-1", to_item_id: "track-2", distance: 0.5, synced_at: Time.current)
    TrackSimilarity.create!(server_connection: @connection, from_item_id: "track-3", to_item_id: "track-1", distance: 0.5, synced_at: Time.current)
    TrackSimilarity.create!(server_connection: @connection, from_item_id: "track-2", to_item_id: "track-3", distance: 0.5, synced_at: Time.current)

    TrackSimilarity.prune_item!(@connection, "track-1")

    assert_equal 1, TrackSimilarity.where(server_connection: @connection).count
    assert_nil TrackSimilarity.find_by(server_connection: @connection, from_item_id: "track-1")
    assert_nil TrackSimilarity.find_by(server_connection: @connection, to_item_id: "track-1")
  end

  test "enforces unique constraint on server connection and item pair" do
    TrackSimilarity.create!(server_connection: @connection, from_item_id: "track-1", to_item_id: "track-2", distance: 0.5, synced_at: Time.current)

    duplicate = TrackSimilarity.new(server_connection: @connection, from_item_id: "track-1", to_item_id: "track-2", distance: 0.3, synced_at: Time.current)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:to_item_id], "has already been taken"
  end
end
