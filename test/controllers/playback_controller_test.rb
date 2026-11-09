require "test_helper"

class PlaybackControllerTest < ActionDispatch::IntegrationTest
  class FakeClient
    def stream_audio(item_id:, range:, access_token:)
      @item_id = item_id
      @range = range
      yield Integrations::AudioStreamResponseData.new(
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

  test "allows the analyzer token to stream audio without a browser session" do
    client = FakeClient.new
    client_class = Integrations::Jellyfin::Client
    original_new = client_class.method(:new)
    client_class.define_singleton_method(:new) { |**_attributes| client }

    begin
      get audio_server_connection_url(@server_connection, "track-id"), headers: { "X-Sonzra-Analyzer-Token" => "development_analyzer_token", "Accept" => "audio/mpeg" }
    ensure
      client_class.define_singleton_method(:new, original_new)
    end

    assert_response :partial_content
    assert_equal "audio-data", response.body
  end

  test "rejects analyzer token in production when ANALYZER_API_KEY is not set" do
    client = FakeClient.new
    client_class = Integrations::Jellyfin::Client
    original_new = client_class.method(:new)
    client_class.define_singleton_method(:new) { |**_attributes| client }

    begin
      with_rails_env("production") do
        with_env("ANALYZER_API_KEY" => nil) do
          get audio_server_connection_url(@server_connection, "track-id"), headers: { "X-Sonzra-Analyzer-Token" => "development_analyzer_token", "Accept" => "audio/mpeg" }
        end
      end
    ensure
      client_class.define_singleton_method(:new, original_new)
    end

    assert_response :unauthorized
  end

  test "accepts valid analyzer token in production when ANALYZER_API_KEY is set" do
    client = FakeClient.new
    client_class = Integrations::Jellyfin::Client
    original_new = client_class.method(:new)
    client_class.define_singleton_method(:new) { |**_attributes| client }

    begin
      with_rails_env("production") do
        with_env("ANALYZER_API_KEY" => "prod_secret_token") do
          get audio_server_connection_url(@server_connection, "track-id"), headers: { "X-Sonzra-Analyzer-Token" => "prod_secret_token", "Accept" => "audio/mpeg" }
        end
      end
    ensure
      client_class.define_singleton_method(:new, original_new)
    end

    assert_response :partial_content
    assert_equal "audio-data", response.body
  end

  test "rejects mismatched analyzer token in production even if ANALYZER_API_KEY is set" do
    client = FakeClient.new
    client_class = Integrations::Jellyfin::Client
    original_new = client_class.method(:new)
    client_class.define_singleton_method(:new) { |**_attributes| client }

    begin
      with_rails_env("production") do
        with_env("ANALYZER_API_KEY" => "prod_secret_token") do
          get audio_server_connection_url(@server_connection, "track-id"), headers: { "X-Sonzra-Analyzer-Token" => "wrong_token", "Accept" => "audio/mpeg" }
        end
      end
    ensure
      client_class.define_singleton_method(:new, original_new)
    end

    assert_response :unauthorized
  end

  private

  def with_rails_env(env)
    old = Rails.env
    Rails.env = ActiveSupport::StringInquirer.new(env)
    yield
  ensure
    Rails.env = old
  end

  def with_env(hash)
    old = {}
    hash.each do |k, v|
      old[k] = ENV[k]
      if v.nil?
        ENV.delete(k)
      else
        ENV[k] = v
      end
    end
    yield
  ensure
    old.each do |k, v|
      if v.nil?
        ENV.delete(k)
      else
        ENV[k] = v
      end
    end
  end
end
