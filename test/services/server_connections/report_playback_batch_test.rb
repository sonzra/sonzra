require "test_helper"

module ServerConnections
  class ReportPlaybackBatchTest < ActiveSupport::TestCase
    class FakeClient
      attr_reader :reported_events, :updated_positions

      def initialize(remote_last_played_date: nil)
        @remote_last_played_date = remote_last_played_date
        @reported_events = []
        @updated_positions = []
      end

      def report_playback(event:, item_id:, position_ticks:, paused:, duration_ticks: 0, access_token: nil)
        @reported_events << { event:, item_id:, position_ticks:, paused:, duration_ticks: }
        Integrations::Jellyfin::PlaybackReportResponseData.new(access_token: "token-123")
      end

      def update_playback_position(item_id:, position_ticks:, access_token: nil)
        @updated_positions << { item_id:, position_ticks: }
        Integrations::Jellyfin::PlaybackReportResponseData.new(access_token: "token-123")
      end

      def library_item_details(item_id)
        details = {
          item: {
            "Id" => item_id,
            "UserData" => {
              "LastPlayedDate" => @remote_last_played_date
            }
          }
        }
        Integrations::Jellyfin::LibraryItemDetailsResponseData.new(details:, access_token: "token-123")
      end
    end

    setup do
      @user = users(:one)
      @server_connection = ServerConnection.create!(
        name: "Sync Server",
        provider: :jellyfin,
        base_url: "https://jellyfin.example.com",
        username: "bruno",
        password: "secret",
        user: @user
      )
    end

    test "creates listening_events with historical occurred_at timestamps" do
      client = FakeClient.new
      occurred_at = 2.hours.ago.change(usec: 0)

      events = [
        {
          event: "started",
          item_id: "track-1",
          position_ticks: 0,
          occurred_at: occurred_at.iso8601,
          paused: false,
          resumable: false
        },
        {
          event: "stopped",
          item_id: "track-1",
          position_ticks: 1800000000,
          occurred_at: (occurred_at + 3.minutes).iso8601,
          paused: false,
          resumable: false
        }
      ]

      assert_difference -> { @user.listening_events.count }, 1 do
        result = ReportPlaybackBatch.new(
          @server_connection,
          events: events,
          user: @user,
          client: client
        ).call

        assert result.success?
        assert_equal 2, result.synced_count
      end

      created_event = @user.listening_events.last
      assert_equal "track-1", created_event.item_id
      assert_equal occurred_at, created_event.occurred_at
    end

    test "suppresses duplicate listening_events on batch replay" do
      client = FakeClient.new
      occurred_at = 1.hour.ago.change(usec: 0)

      event = {
        event: "started",
        item_id: "track-duplicate",
        position_ticks: 0,
        occurred_at: occurred_at.iso8601,
        paused: false
      }

      # First batch run
      ReportPlaybackBatch.new(@server_connection, events: [ event ], user: @user, client: client).call
      assert_equal 1, @user.listening_events.where(item_id: "track-duplicate").count

      # Replay same batch run
      assert_no_difference -> { @user.listening_events.count } do
        result = ReportPlaybackBatch.new(@server_connection, events: [ event ], user: @user, client: client).call
        assert result.success?
      end
    end

    test "updates remote resume position when client occurred_at is newer than server LastPlayedDate" do
      client = FakeClient.new(remote_last_played_date: 3.hours.ago.iso8601)
      client_occurred_at = 1.hour.ago.iso8601

      event = {
        event: "progress",
        item_id: "audiobook-1",
        position_ticks: 50_000_000_000,
        occurred_at: client_occurred_at,
        paused: false,
        resumable: true
      }

      result = ReportPlaybackBatch.new(@server_connection, events: [ event ], user: @user, client: client).call
      assert result.success?
      assert_equal 1, client.updated_positions.size
      assert_equal 50_000_000_000, client.updated_positions.first[:position_ticks]
    end

    test "does not overwrite remote resume position when client occurred_at is older than server LastPlayedDate" do
      client = FakeClient.new(remote_last_played_date: 30.minutes.ago.iso8601)
      client_occurred_at = 2.hours.ago.iso8601

      event = {
        event: "progress",
        item_id: "audiobook-1",
        position_ticks: 10_000_000_000,
        occurred_at: client_occurred_at,
        paused: false,
        resumable: true
      }

      result = ReportPlaybackBatch.new(@server_connection, events: [ event ], user: @user, client: client).call
      assert result.success?
      assert_empty client.updated_positions
    end

    test "memoizes library_item_details across events with the same item_id" do
      client = FakeClient.new(remote_last_played_date: 3.hours.ago.iso8601)
      call_count = 0
      client.define_singleton_method(:library_item_details) do |item_id|
        call_count += 1
        super(item_id)
      end

      events = [
        { event: "progress", item_id: "audiobook-memo", position_ticks: 1000, occurred_at: 1.hour.ago.iso8601, paused: false, resumable: true },
        { event: "progress", item_id: "audiobook-memo", position_ticks: 2000, occurred_at: 50.minutes.ago.iso8601, paused: false, resumable: true }
      ]

      result = ReportPlaybackBatch.new(@server_connection, events: events, user: @user, client: client).call
      assert result.success?
      assert_equal 1, call_count
    end
  end
end
