require "test_helper"

class SonicGraph::BuilderTest < ActiveSupport::TestCase
  setup do
    @connection = ServerConnection.create!(
      name: "Library",
      provider: :jellyfin,
      base_url: "https://jellyfin.example.com",
      username: "bruno",
      password: "secret",
      user: users(:one)
    )
  end

  test "populates track similarity edges from client" do
    client = Object.new
    client.define_singleton_method(:supports?) { |capability| capability == Integrations::Capabilities::SONIC_GRAPH }
    client.define_singleton_method(:all_track_ids) { [ "track-1", "track-2" ] }
    client.define_singleton_method(:similar_tracks_for) do |item_id, limit: 20|
      item_id == "track-1" ? [ { id: "track-2", distance: 0.3 } ] : []
    end

    SonicGraph::Builder.new(@connection, client:).call

    assert_equal 1, TrackSimilarity.where(server_connection: @connection).count
    similarity = TrackSimilarity.find_by(server_connection: @connection, from_item_id: "track-1")
    assert_equal "track-2", similarity.to_item_id
    assert_equal 0.3, similarity.distance
  end

  test "skips execution if client does not support sonic graph" do
    client = Object.new
    client.define_singleton_method(:supports?) { |_| false }

    SonicGraph::Builder.new(@connection, client:).call

    assert_equal 0, TrackSimilarity.where(server_connection: @connection).count
  end
end
