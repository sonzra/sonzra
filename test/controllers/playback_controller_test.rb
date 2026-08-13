require "test_helper"

class PlaybackControllerTest < ActionDispatch::IntegrationTest
  class FakeClient
    def stream_audio(item_id:, range:, access_token:)
      @item_id = item_id
      @range = range
      yield Integrations::Jellyfin::AudioStreamResponseData.new(
        body: "audio-data",
        accept_ranges: "bytes",
        content_type: "audio/mpeg",
        content_length: "10",
        content_range: "bytes 0-9/10",
        status: 206
      )
      yield "audio-data"
    end
  end

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

  test "proxies a ranged audio stream" do
    client = FakeClient.new

    client_class = Integrations::Jellyfin::Client
    original_new = client_class.method(:new)
    client_class.define_singleton_method(:new) { |**_attributes| client }

    begin
      get audio_server_connection_url(@server_connection, "track-id"), headers: { "Range" => "bytes=0-" }
    ensure
      client_class.define_singleton_method(:new, original_new)
    end

    assert_response :partial_content
    assert_equal "audio/mpeg", response.media_type
    assert_equal "bytes 0-9/10", response.headers["Content-Range"]
    assert_equal "bytes", response.headers["Accept-Ranges"]
    assert_equal "audio-data", response.body
  end

  test "does not treat a cancelled browser audio request as a server error" do
    client = Class.new do
      def stream_audio(**)
        yield "audio-data"
      end
    end.new
    client_class = Integrations::Jellyfin::Client
    original_new = client_class.method(:new)
    client_class.define_singleton_method(:new) { |**_attributes| client }
    original_write = ActionController::Live::Buffer.instance_method(:write)
    ActionController::Live::Buffer.define_method(:write) { |_part| raise ActionController::Live::ClientDisconnected }

    begin
      get audio_server_connection_url(@server_connection, "track-id")
    ensure
      client_class.define_singleton_method(:new, original_new)
      ActionController::Live::Buffer.define_method(:write, original_write)
    end

    assert_not_equal 500, response.status
  end
end
