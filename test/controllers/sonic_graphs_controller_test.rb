require "test_helper"

class SonicGraphsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    sign_in_as(@user)
    @connection = ServerConnection.create!(
      name: "Library",
      provider: :jellyfin,
      base_url: "https://jellyfin.example.com",
      username: "bruno",
      password: "secret",
      user: @user
    )
  end

  test "shows sonic graph page and json endpoint" do
    track = { "Id" => "track-1", "Name" => "Track 1", "AlbumArtist" => "Artist 1", "RunTimeTicks" => 1_800_000_000 }
    client = Object.new
    client.define_singleton_method(:recommendation_tracks_by_ids) { |ids| ids.map { |_| track } }

    original_for = Integrations::Client.method(:for)
    Integrations::Client.define_singleton_method(:for) { |*_args| client }

    begin
      get sonic_graph_server_connection_path(@connection, "track-1")
      assert_response :success
      assert_select "h1", "Sonic Music Map"

      get sonic_graph_server_connection_path(@connection, "track-1"), as: :json
      assert_response :success
      json = JSON.parse(response.body)
      assert_equal "track-1", json.dig("center", "item_id")
    ensure
      Integrations::Client.define_singleton_method(:for, original_for)
    end
  end

  test "builds a bounded artist map from several strong track comparisons" do
    [ [ "a-1", "Artist A" ], [ "a-2", "Artist A" ], [ "b-1", "Artist B" ], [ "b-2", "Artist B" ], [ "c-1", "Artist C" ] ].each do |item_id, artist|
      SonicGraphNode.create!(
        server_connection: @connection,
        item_id:,
        title: item_id,
        artist:,
        analysis_version: SonicGraphNode::CURRENT_ANALYSIS_VERSION,
        synced_at: Time.current
      )
    end
    [ [ "a-1", "b-1", 0.18 ], [ "a-2", "b-2", 0.28 ], [ "a-1", "c-1", 0.49 ] ].each do |from_item_id, to_item_id, distance|
      TrackSimilarity.create!(server_connection: @connection, from_item_id:, to_item_id:, distance:, analysis_version: SonicGraphNode::CURRENT_ANALYSIS_VERSION, synced_at: Time.current)
      TrackSimilarity.create!(server_connection: @connection, from_item_id: to_item_id, to_item_id: from_item_id, distance:, analysis_version: SonicGraphNode::CURRENT_ANALYSIS_VERSION, synced_at: Time.current)
    end

    get sonic_graph_path, as: :json

    assert_response :success
    json = JSON.parse(response.body)
    assert_equal 3, json.fetch("nodes").size
    assert_equal [ { "from" => "Artist A", "to" => "Artist B", "distance" => 0.23, "evidence" => 2 } ], json.fetch("edges")
  end

  test "does not connect artists from a single accidental track match" do
    [ [ "a-1", "Artist A" ], [ "a-2", "Artist A" ], [ "b-1", "Artist B" ], [ "b-2", "Artist B" ] ].each do |item_id, artist|
      SonicGraphNode.create!(server_connection: @connection, item_id:, title: item_id, artist:, analysis_version: SonicGraphNode::CURRENT_ANALYSIS_VERSION, synced_at: Time.current)
    end
    TrackSimilarity.create!(server_connection: @connection, from_item_id: "a-1", to_item_id: "b-1", distance: 0.03, analysis_version: SonicGraphNode::CURRENT_ANALYSIS_VERSION, synced_at: Time.current)

    get sonic_graph_path, as: :json

    assert_response :success
    assert_empty JSON.parse(response.body).fetch("edges")
  end
end
