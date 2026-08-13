module ServerConnections
  class ResetPlaybackPosition
    def initialize(server_connection, item_id:, access_token:, report_playback: nil)
      @server_connection = server_connection
      @item_id = item_id
      @access_token = access_token
      @report_playback = report_playback
    end

    def call
      report_playback.call
    end

    private

    attr_reader :server_connection, :item_id, :access_token

    def report_playback
      @report_playback ||= ReportPlayback.new(
        server_connection,
        event: "stopped",
        item_id: item_id,
        position_ticks: 0,
        paused: true,
        reset_position: true,
        access_token: access_token
      )
    end
  end
end
