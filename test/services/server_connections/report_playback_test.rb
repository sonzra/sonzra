require "test_helper"

class ServerConnections::ReportPlaybackTest < ActiveSupport::TestCase
  test "forwards the playback state to the integration client" do
    client = Object.new
    client.define_singleton_method(:report_playback) do |**attributes|
      @attributes = attributes
      Integrations::Jellyfin::PlaybackReportResponseData.new(access_token: "token")
    end
    server_connection = ServerConnection.new(name: "Home", provider: :jellyfin, base_url: "https://example.com", username: "bruno", password: "secret")

    result = ServerConnections::ReportPlayback.new(
      server_connection,
      event: "started",
      item_id: "track-id",
      position_ticks: 0,
      duration_ticks: 180_000_000,
      paused: false,
      access_token: "session-token",
      client: client
    ).call

    assert result.success?
    assert_equal "token", result.access_token
    assert_equal "track-id", client.instance_variable_get(:@attributes)[:item_id]
    assert_equal "session-token", client.instance_variable_get(:@attributes)[:access_token]
    assert_equal 180_000_000, client.instance_variable_get(:@attributes)[:duration_ticks]
  end

  test "forwards device_id and access_token to integration client when client is not injected" do
    server_connection = ServerConnection.new(name: "Home", provider: :jellyfin, base_url: "https://example.com", username: "bruno", password: "secret")
    fake_client = Object.new
    fake_client.define_singleton_method(:report_playback) do |**|
      Integrations::Jellyfin::PlaybackReportResponseData.new(access_token: "token")
    end

    original_for = Integrations::Client.method(:for)
    received_options = nil
    Integrations::Client.define_singleton_method(:for) do |_conn, **options|
      received_options = options
      fake_client
    end

    begin
      result = ServerConnections::ReportPlayback.new(
        server_connection,
        event: "progress",
        item_id: "track-id",
        position_ticks: 50_000,
        paused: false,
        access_token: "test-token",
        device_id: "custom-device-id"
      ).call

      assert result.success?
      assert_equal "custom-device-id", received_options[:device_id]
      assert_equal "test-token", received_options[:access_token]
    ensure
      Integrations::Client.define_singleton_method(:for, original_for)
    end
  end
end
