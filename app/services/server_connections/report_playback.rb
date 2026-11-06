module ServerConnections
  class ReportPlayback
    EVENTS = %w[started progress stopped].freeze

    def initialize(server_connection, event:, item_id:, position_ticks:, paused:, duration_ticks: 0, resumable: false, reset_position: false, access_token:, device_id: nil, client: nil, client_occurred_at: nil)
      @server_connection = server_connection
      @event = event
      @item_id = item_id
      @position_ticks = position_ticks
      @paused = paused
      @duration_ticks = duration_ticks
      @resumable = resumable
      @reset_position = reset_position
      @access_token = access_token
      @device_id = device_id
      @client = client
      @client_occurred_at = client_occurred_at
    end

    def call
      response = client.report_playback(
        event: event,
        item_id: item_id,
        position_ticks: position_ticks,
        paused: paused,
        duration_ticks: duration_ticks,
        access_token: access_token
      )
      response = client.update_playback_position(item_id: item_id, position_ticks: position_ticks, access_token: response.access_token) if update_position?
      PlaybackReportResultData.new(access_token: response.access_token, message: nil)
    rescue Integrations::AuthenticationError, Integrations::ConnectionError => error
      PlaybackReportResultData.new(access_token: nil, message: error.message.presence || "Could not report playback.")
    end

    private

    attr_reader :server_connection, :event, :item_id, :position_ticks, :paused, :duration_ticks, :resumable, :reset_position, :access_token, :client_occurred_at

    def update_position?
      return true if reset_position

      resumable && event.in?([ "progress", "stopped" ]) && position_ticks.positive? && client_newer_than_server?
    end

    def client_newer_than_server?
      return true if client_occurred_at.blank?

      parsed_client_time = client_occurred_at.is_a?(Time) ? client_occurred_at : Time.zone.parse(client_occurred_at.to_s)
      return true if parsed_client_time.blank?

      remote_last_played = remote_last_played_date
      return true if remote_last_played.blank?

      parsed_client_time >= remote_last_played
    rescue StandardError
      true
    end

    def remote_last_played_date
      return nil unless client.respond_to?(:library_item_details)

      item_details = client.library_item_details(item_id)&.details
      last_played_raw = item_details&.dig(:item, "UserData", "LastPlayedDate") || item_details&.dig(:item, "DatePlayed")
      Time.zone.parse(last_played_raw.to_s) if last_played_raw.present?
    rescue StandardError
      nil
    end

    def client
      @client ||= Integrations::Client.for(server_connection, access_token: access_token, device_id: @device_id)
    end
  end
end
