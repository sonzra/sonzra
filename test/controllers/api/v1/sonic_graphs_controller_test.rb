require "test_helper"

module Api
  module V1
    class SonicGraphsControllerTest < ActionDispatch::IntegrationTest
      setup do
        @user = users(:one)
        @server_connection = ServerConnection.create!(
          name: "Test Connection",
          provider: :jellyfin,
          base_url: "https://jellyfin.example.com",
          username: "bruno",
          password: "secret",
          user: @user
        )
        @token = "development_analyzer_token"
      end

      test "status returns unanalyzed pending tracks" do
        client = Object.new
        client.define_singleton_method(:all_track_ids) { [ "track-1" ] }
        client.define_singleton_method(:recommendation_tracks_by_ids) { |_ids| [ { "Id" => "track-1", "Name" => "Track 1", "AlbumArtist" => "Artist", "RunTimeTicks" => 213_000_000 } ] }
        original_for = Integrations::Client.method(:for)
        Integrations::Client.define_singleton_method(:for) { |*_arguments| client }

        get status_api_v1_sonic_graph_url, headers: { "X-Sonzra-Analyzer-Token" => @token, "X-Sonzra-Analysis-Version" => "v2" }
        assert_response :success
        json = JSON.parse(response.body)
        assert_equal "ok", json["status"]
        assert_equal "v2", json["analysis_version"]
        assert_equal [ "track-1" ], json.fetch("pending_tracks").pluck("item_id")
        assert_equal 21.3, json.fetch("pending_tracks").first.fetch("duration_seconds")
        assert json.key?("pending_count")
      ensure
        Integrations::Client.define_singleton_method(:for, original_for)
      end

      test "status rejects unauthorized analyzer token" do
        get status_api_v1_sonic_graph_url, headers: { "X-Sonzra-Analyzer-Token" => "invalid_token" }
        assert_response :unauthorized
      end

      test "status can limit a calibration run to selected artists" do
        client = Object.new
        requested_artists = nil
        client.define_singleton_method(:sonic_graph_track_ids_for_artists) { |artists| requested_artists = artists; [ "track-1" ] }
        client.define_singleton_method(:recommendation_tracks_by_ids) { |_ids| [ { "Id" => "track-1", "Name" => "Track 1", "AlbumArtist" => "Resgate" } ] }
        original_for = Integrations::Client.method(:for)
        Integrations::Client.define_singleton_method(:for) { |*_arguments| client }

        get status_api_v1_sonic_graph_url(artists: "Resgate,Rodolfo Abrantes,Ao Cubo"), headers: { "X-Sonzra-Analyzer-Token" => @token, "X-Sonzra-Analysis-Version" => "v3" }

        assert_response :success
        assert_equal [ "Resgate", "Rodolfo Abrantes", "Ao Cubo" ], requested_artists
        assert_equal [ "track-1" ], JSON.parse(response.body).fetch("pending_tracks").pluck("item_id")
      ensure
        Integrations::Client.define_singleton_method(:for, original_for)
      end

      test "edges upserts acoustic edges and nodes" do
        payload = {
          server_connection_id: @server_connection.id,
          nodes: [
            { item_id: "track_test_101", title: "Test Track 101", artist: "Test Artist", feature_vector: { bpm: 120, mfcc: [ 0.2, 0.4 ] } }
          ],
          edges: [
            { from_item_id: "track_test_101", to_item_id: "track_test_102", distance: 0.125 }
          ]
        }

        post edges_api_v1_sonic_graph_url, params: payload, as: :json, headers: { "X-Sonzra-Analyzer-Token" => @token, "X-Sonzra-Analysis-Version" => "v2" }
        assert_response :success
        json = JSON.parse(response.body)
        assert_equal "success", json["status"]
        assert_equal 1, json["nodes_upserted"]
        assert_equal 1, json["edges_upserted"]

        assert TrackSimilarity.exists?(server_connection: @server_connection, from_item_id: "track_test_101", to_item_id: "track_test_102")
        assert SonicGraphNode.exists?(server_connection: @server_connection, item_id: "track_test_101")
        assert_equal "v2", SonicGraphNode.find_by!(server_connection: @server_connection, item_id: "track_test_101").analysis_version
      end

      test "returns saved feature vectors for the requested analysis version" do
        SonicGraphNode.create!(server_connection: @server_connection, item_id: "track-1", title: "Track", analysis_version: "v2", feature_vector: { bpm: 128 }, synced_at: Time.current)
        SonicGraphNode.create!(server_connection: @server_connection, item_id: "track-2", title: "Old track", analysis_version: "v1", feature_vector: { bpm: 100 }, synced_at: Time.current)

        get features_api_v1_sonic_graph_url, headers: { "X-Sonzra-Analyzer-Token" => @token, "X-Sonzra-Analysis-Version" => "v2" }

        assert_response :success
        assert_equal [ { "item_id" => "track-1", "artist" => nil, "vector" => { "bpm" => 128 } } ], JSON.parse(response.body).fetch("features")
      end

      test "replaces an analysed track's stale outgoing edges" do
        TrackSimilarity.create!(server_connection: @server_connection, from_item_id: "track-1", to_item_id: "old-track", distance: 0.3, synced_at: Time.current)

        post edges_api_v1_sonic_graph_url,
             params: { server_connection_id: @server_connection.id, replace_from_item_ids: [ "track-1" ], edges: [ { from_item_id: "track-1", to_item_id: "new-track", distance: 0.2 } ] },
             as: :json,
             headers: { "X-Sonzra-Analyzer-Token" => @token, "X-Sonzra-Analysis-Version" => "v2" }

        assert_response :success
        assert_not TrackSimilarity.exists?(server_connection: @server_connection, from_item_id: "track-1", to_item_id: "old-track")
        assert TrackSimilarity.exists?(server_connection: @server_connection, from_item_id: "track-1", to_item_id: "new-track")
      end
    end
  end
end
