require "test_helper"

class LyricsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @server_connection = ServerConnection.create!(
      media_server: MediaServer.create!(name: "Home server", provider: :jellyfin, base_url: "https://jellyfin.example.com"),
      username: "bruno",
      password: "secret",
      user: users(:one)
    )
  end

  test "returns sanitized lyrics for the player" do
    result = ServerConnections::FetchLyricsResultData.new(
      lines: [ { text: "A line", start: 12.3 } ], access_token: "token", available: true, synchronized: true, message: nil
    )
    service = Object.new
    service.define_singleton_method(:call) { result }
    service_class = ServerConnections::FetchLyrics
    original_new = service_class.method(:new)
    service_class.define_singleton_method(:new) { |*_arguments| service }

    get lyrics_server_connection_url(@server_connection, "track-id")

    assert_response :success
    assert_equal({ "available" => true, "synchronized" => true, "lines" => [ { "text" => "A line", "start" => 12.3 } ] }, JSON.parse(response.body))
    assert_equal "token", session[:server_access_tokens][@server_connection.id.to_s]
  ensure
    service_class.define_singleton_method(:new, original_new)
  end
end
