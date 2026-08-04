require "test_helper"

class RadioTracksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @server_connection = ServerConnection.create!(
      media_server: MediaServer.create!(name: "Home server", provider: :jellyfin, base_url: "https://jellyfin.example.com"),
      username: "bruno",
      password: "secret",
      user: users(:one)
    )
  end

  test "returns radio tracks for the player queue" do
    result = ServerConnections::FetchRadioTracksResultData.new(
      items: [
        {
          "Id" => "track-1",
          "Name" => "Instant mix track",
          "AlbumArtist" => "Artist",
          "RunTimeTicks" => 210_000_000,
          "UserData" => { "IsFavorite" => true }
        }
      ],
      access_token: "token",
      message: nil
    )
    service = Object.new
    service.define_singleton_method(:call) { result }

    service_class = ServerConnections::FetchRadioTracks
    original_new = service_class.method(:new)
    service_class.define_singleton_method(:new) { |*_arguments| service }

    get radio_tracks_server_connection_url(@server_connection, "seed-track")

    assert_response :success
    payload = JSON.parse(response.body)
    assert_equal "track-1", payload.dig("items", 0, "item_id")
    assert_equal true, payload.dig("items", 0, "favorite")
    assert_equal true, payload.dig("items", 0, "radio_eligible")
    assert_equal radio_tracks_server_connection_path(@server_connection, "track-1"), payload.dig("items", 0, "radio_url")
    assert_equal "token", session[:server_access_tokens][@server_connection.id.to_s]
  ensure
    service_class.define_singleton_method(:new, original_new)
  end
end
