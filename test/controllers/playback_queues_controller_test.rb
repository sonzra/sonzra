require "test_helper"

class PlaybackQueuesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @server_connection = ServerConnection.create!(
      name: "Playback server",
      provider: :jellyfin,
      base_url: "https://jellyfin.example.com",
      username: "bruno",
      password: "secret",
      user: users(:one)
    )
  end

  test "returns each queued track's own album metadata" do
    result = ServerConnections::FetchPlaybackQueueResultData.new(
      items: [
        { "Id" => "track-1", "Name" => "First", "AlbumId" => "album-1", "Album" => "First album", "AlbumArtist" => "Artist one" },
        { "Id" => "track-2", "Name" => "Second", "AlbumId" => "album-2", "Album" => "Second album", "AlbumArtist" => "Artist two" }
      ],
      access_token: "token",
      message: nil
    )
    service = Object.new
    service.define_singleton_method(:call) { result }
    service_class = ServerConnections::FetchPlaybackQueue
    original_new = service_class.method(:new)
    service_class.define_singleton_method(:new) { |*_arguments| service }

    get playback_queue_server_connection_url(@server_connection, "artist-id")

    assert_response :success
    payload = JSON.parse(response.body)
    assert_equal "album-1", payload.dig("items", 0, "album_id")
    assert_equal "First album", payload.dig("items", 0, "album")
    assert_equal "album-2", payload.dig("items", 1, "album_id")
    assert_equal "Second album", payload.dig("items", 1, "album")
  ensure
    service_class.define_singleton_method(:new, original_new)
  end
end
