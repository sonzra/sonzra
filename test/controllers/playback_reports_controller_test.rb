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

  test "accepts batched playback reports" do
    client_class = Integrations::Jellyfin::Client
    original_new = client_class.method(:new)
    client_class.define_singleton_method(:new) { |**_attributes| FakeClient.new }

    occurred_at = 2.hours.ago.change(usec: 0).iso8601

    begin
      assert_difference "ListeningEvent.count", 1 do
        post batch_playback_reports_server_connection_url(@server_connection), params: {
          events: [
            { event: "started", item_id: "batch-track", position_ticks: 0, paused: false, occurred_at: occurred_at },
            { event: "stopped", item_id: "batch-track", position_ticks: 1000, paused: false, occurred_at: occurred_at }
          ]
        }, as: :json
      end
    ensure
      client_class.define_singleton_method(:new, original_new)
    end

    assert_response :no_content
    assert_equal "batch-track", ListeningEvent.last.item_id
  end

  test "rejects batch reports exceeding maximum batch size" do
    large_events = Array.new(101) do |i|
      { event: "started", item_id: "track-#{i}", position_ticks: 0, paused: false, occurred_at: Time.current.iso8601 }
    end

    post batch_playback_reports_server_connection_url(@server_connection), params: {
      events: large_events
    }, as: :json

    assert_response :unprocessable_entity
  end
end
