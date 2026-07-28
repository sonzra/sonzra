module ServerConnections
  class ReportPlayback
    EVENTS = %w[started progress stopped].freeze

    def initialize(server_connection, event:, item_id:, position_ticks:, paused:, access_token:, client: nil)
      @server_connection = server_connection
      @event = event
      @item_id = item_id
      @position_ticks = position_ticks
      @paused = paused
      @access_token = access_token
      @client = client
    end

    def call
      response = client.report_playback(
        event: event,
        item_id: item_id,
        position_ticks: position_ticks,
        paused: paused,
        access_token: access_token
      )
      PlaybackReportResultData.new(access_token: response.access_token, message: nil)
    rescue Integrations::Jellyfin::Client::AuthenticationError, Integrations::Jellyfin::Client::ConnectionError => error
      PlaybackReportResultData.new(access_token: nil, message: error.message.presence || "Could not report playback.")
    end

    private

    attr_reader :server_connection, :event, :item_id, :position_ticks, :paused, :access_token

    def client
      @client ||= Integrations::Jellyfin::Client.new(
        base_url: server_connection.base_url,
        username: server_connection.username,
        password: server_connection.password
      )
    end
  end
end
