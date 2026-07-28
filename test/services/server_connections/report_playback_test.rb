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
      paused: false,
      access_token: "session-token",
      client: client
    ).call

    assert result.success?
    assert_equal "token", result.access_token
    assert_equal "track-id", client.instance_variable_get(:@attributes)[:item_id]
    assert_equal "session-token", client.instance_variable_get(:@attributes)[:access_token]
  end
end
