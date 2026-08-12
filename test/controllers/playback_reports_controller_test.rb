require "test_helper"

class PlaybackReportsControllerTest < ActionDispatch::IntegrationTest
  class FakeClient
    def report_playback(**)
      Integrations::Jellyfin::PlaybackReportResponseData.new(access_token: "token")
    end
  end

  setup do
    @server_connection = ServerConnection.create!(
      name: "Reporting server",
      provider: :jellyfin,
      base_url: "https://jellyfin.example.com",
      username: "bruno",
      password: "secret",
      user: users(:one)
    )
  end

  test "reports playback state to Jellyfin" do
    client_class = Integrations::Jellyfin::Client
    original_new = client_class.method(:new)
    client_class.define_singleton_method(:new) { |**_attributes| FakeClient.new }

    begin
      assert_difference "ListeningEvent.count", 1 do
        post playback_reports_server_connection_url(@server_connection), params: {
          event: "started", item_id: "track-id", position_ticks: 0, paused: false
        }
      end
    ensure
      client_class.define_singleton_method(:new, original_new)
    end

    assert_response :no_content
    assert_equal "track-id", ListeningEvent.last.item_id
  end

  test "rejects unknown playback events" do
    post playback_reports_server_connection_url(@server_connection), params: {
      event: "unknown", item_id: "track-id", position_ticks: 0, paused: false
    }

    assert_response :unprocessable_entity
  end
end
