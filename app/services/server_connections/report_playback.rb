module ServerConnections
  class ReportPlayback
    EVENTS = %w[started progress stopped].freeze

    def initialize(server_connection, event:, item_id:, position_ticks:, paused:, duration_ticks: 0, resumable: false, reset_position: false, access_token:, client: nil)
      @server_connection = server_connection
      @event = event
      @item_id = item_id
      @position_ticks = position_ticks
      @paused = paused
      @duration_ticks = duration_ticks
      @resumable = resumable
      @reset_position = reset_position
      @access_token = access_token
      @client = client
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
    rescue Integrations::Jellyfin::Client::AuthenticationError, Integrations::Jellyfin::Client::ConnectionError => error
      PlaybackReportResultData.new(access_token: nil, message: error.message.presence || "Could not report playback.")
    end

    private

    attr_reader :server_connection, :event, :item_id, :position_ticks, :paused, :duration_ticks, :resumable, :reset_position, :access_token

    def update_position?
      reset_position || (resumable && event.in?([ "progress", "stopped" ]) && position_ticks.positive?)
    end

    def client
      @client ||= Integrations::Client.for(server_connection)
    end
  end
end
