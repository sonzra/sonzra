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
end
