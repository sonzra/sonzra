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
        get status_api_v1_sonic_graph_url, headers: { "X-Sonzra-Analyzer-Token" => @token }
        assert_response :success
        json = JSON.parse(response.body)
        assert_equal "ok", json["status"]
        assert json.key?("pending_count")
      end

      test "status rejects unauthorized analyzer token" do
        get status_api_v1_sonic_graph_url, headers: { "X-Sonzra-Analyzer-Token" => "invalid_token" }
        assert_response :unauthorized
      end

      test "edges upserts acoustic edges and nodes" do
        payload = {
          server_connection_id: @server_connection.id,
          nodes: [
            { item_id: "track_test_101", title: "Test Track 101", artist: "Test Artist" }
          ],
          edges: [
            { from_item_id: "track_test_101", to_item_id: "track_test_102", distance: 0.125 }
          ]
        }

        post edges_api_v1_sonic_graph_url, params: payload, as: :json, headers: { "X-Sonzra-Analyzer-Token" => @token }
        assert_response :success
        json = JSON.parse(response.body)
        assert_equal "success", json["status"]
        assert_equal 1, json["nodes_upserted"]
        assert_equal 1, json["edges_upserted"]

        assert TrackSimilarity.exists?(server_connection: @server_connection, from_item_id: "track_test_101", to_item_id: "track_test_102")
        assert SonicGraphNode.exists?(server_connection: @server_connection, item_id: "track_test_101")
      end
    end
  end
end
