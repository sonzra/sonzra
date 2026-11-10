require "test_helper"

module Api
  module V1
    class PlaybackReportsControllerTest < ActionDispatch::IntegrationTest
      class FakeClient
        def report_playback(**)
          Integrations::PlaybackReportResponseData.new(access_token: "token")
        end

        def update_playback_position(**)
          Integrations::PlaybackReportResponseData.new(access_token: "token")
        end
      end

      setup do
        @user = users(:one)
        @server_connection = ServerConnection.create!(
          name: "Reporting server",
          provider: :jellyfin,
          base_url: "https://jellyfin.example.com",
          username: "bruno",
          password: "secret",
          user: @user
        )
      end

      test "requires authentication" do
        sign_out
        post api_v1_playback_reports_url, params: { event: "progress", item_id: "trk-1", position_ticks: 1000 }
        assert_response :unauthorized
        json = JSON.parse(response.body)
        assert_equal "Unauthorized", json["error"]
      end

      test "authenticates with Bearer token" do
        sign_out
        token = @user.generate_token_for(:api_token)

        client_class = Integrations::Jellyfin::Client
        original_new = client_class.method(:new)
        client_class.define_singleton_method(:new) { |**| FakeClient.new }

        post api_v1_playback_reports_url,
          params: { event: "progress", item_id: "trk-1", position_ticks: 10_000_000 },
          headers: { "Authorization" => "Bearer #{token}" }

        assert_response :ok
        json = JSON.parse(response.body)
        assert_equal "ok", json["status"]
      ensure
        client_class.define_singleton_method(:new, original_new)
      end

      test "reports started playback and creates listening event" do
        client_class = Integrations::Jellyfin::Client
        original_new = client_class.method(:new)
        client_class.define_singleton_method(:new) { |**| FakeClient.new }

        assert_difference "ListeningEvent.count", 1 do
          post api_v1_playback_reports_url, params: {
            event: "started",
            item_id: "track-123",
            position_ticks: 0,
            paused: false
          }
        end

        assert_response :ok
        json = JSON.parse(response.body)
        assert_equal "ok", json["status"]
        assert_equal "track-123", ListeningEvent.last.item_id
      ensure
        client_class.define_singleton_method(:new, original_new)
      end

      test "reports progress with position_seconds" do
        received_args = nil
        fake_client = Object.new
        fake_client.define_singleton_method(:report_playback) do |**args|
          received_args = args
          Integrations::PlaybackReportResponseData.new(access_token: "tok")
        end

        original_for = Integrations::Client.method(:for)
        Integrations::Client.define_singleton_method(:for) { |*, **| fake_client }

        post api_v1_playback_reports_url, params: {
          event: "progress",
          item_id: "track-456",
          position_seconds: 45.5,
          duration_seconds: 180,
          paused: false
        }

        assert_response :ok
        assert_equal "progress", received_args[:event]
        assert_equal "track-456", received_args[:item_id]
        assert_equal 455_000_000, received_args[:position_ticks]
        assert_equal 1_800_000_000, received_args[:duration_ticks]
      ensure
        Integrations::Client.define_singleton_method(:for, original_for)
      end

      test "accepts completed event and normalizes to stopped" do
        received_args = nil
        fake_client = Object.new
        fake_client.define_singleton_method(:report_playback) do |**args|
          received_args = args
          Integrations::PlaybackReportResponseData.new(access_token: "tok")
        end

        original_for = Integrations::Client.method(:for)
        Integrations::Client.define_singleton_method(:for) { |*, **| fake_client }

        post api_v1_playback_reports_url, params: {
          event: "completed",
          item_id: "track-789",
          position_ticks: 1_800_000_000
        }

        assert_response :ok
        assert_equal "stopped", received_args[:event]
      ensure
        Integrations::Client.define_singleton_method(:for, original_for)
      end

      test "rejects invalid playback event" do
        post api_v1_playback_reports_url, params: {
          event: "invalid_event",
          item_id: "track-1"
        }

        assert_response :unprocessable_entity
        json = JSON.parse(response.body)
        assert_includes json["error"], "Invalid playback event"
      end

      test "rejects request with missing item_id" do
        post api_v1_playback_reports_url, params: {
          event: "started"
        }

        assert_response :unprocessable_entity
        json = JSON.parse(response.body)
        assert json["error"].present?
      end

      test "accepts batched playback reports" do
        batch_received = nil
        batch_service = Object.new
        batch_service.define_singleton_method(:call) do
          ServerConnections::PlaybackReportResultData.new(access_token: "tok", message: nil)
        end

        original_new = ServerConnections::ReportPlaybackBatch.method(:new)
        ServerConnections::ReportPlaybackBatch.define_singleton_method(:new) do |_conn, **kwargs|
          batch_received = kwargs[:events]
          batch_service
        end

        post api_v1_playback_reports_url, params: {
          events: [
            { event: "started", item_id: "trk-1", position_ticks: 0 },
            { event: "progress", item_id: "trk-1", position_ticks: 10_000_000 }
          ]
        }

        assert_response :ok
        json = JSON.parse(response.body)
        assert_equal "ok", json["status"]
        assert_equal 2, json["count"]
        assert_equal 2, batch_received.size
      ensure
        ServerConnections::ReportPlaybackBatch.define_singleton_method(:new, original_new)
      end

      test "handles backend error with 502 Bad Gateway" do
        client_class = Integrations::Jellyfin::Client
        original_new = client_class.method(:new)
        client_class.define_singleton_method(:new) do |**|
          f = Object.new
          f.define_singleton_method(:report_playback) do |**|
            raise Integrations::ConnectionError, "Cannot contact server"
          end
          f
        end

        post api_v1_playback_reports_url, params: {
          event: "progress",
          item_id: "track-1",
          position_ticks: 100
        }

        assert_response :bad_gateway
        json = JSON.parse(response.body)
        assert_equal "Cannot contact server", json["error"]
      ensure
        client_class.define_singleton_method(:new, original_new)
      end
    end
  end
end
