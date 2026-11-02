module ServerConnections
  class ReportPlaybackBatch
    class BatchReportError < StandardError; end

    Result = Struct.new(:success?, :synced_count, :access_token, :message, keyword_init: true)

    def initialize(server_connection, events:, user: nil, access_token: nil, client: nil)
      @server_connection = server_connection
      @events = Array(events)
      @user = user || server_connection.user
      @access_token = access_token
      @client = client
    end

    def call
      return Result.new(success?: true, synced_count: 0, access_token: access_token, message: nil) if events.empty?

      current_token = access_token
      synced = 0
      has_stopped = false

      ActiveRecord::Base.transaction do
        events.each do |raw_event|
          ev = normalize_event(raw_event)
          next unless ServerConnections::ReportPlayback::EVENTS.include?(ev[:event])
          next if ev[:item_id].blank?

          if ev[:event] == "started"
            create_listening_event_if_missing(ev)
          end

          has_stopped = true if ev[:event] == "stopped"

          report_result = ServerConnections::ReportPlayback.new(
            server_connection,
            event: ev[:event],
            item_id: ev[:item_id],
            position_ticks: ev[:position_ticks],
            paused: ev[:paused],
            duration_ticks: ev[:duration_ticks],
            resumable: ev[:resumable],
            access_token: current_token,
            client_occurred_at: ev[:occurred_at],
            client: client
          ).call

          unless report_result.success?
            raise BatchReportError, report_result.message
          end

          current_token = report_result.access_token if report_result.access_token.present?
          synced += 1
        end

        ServerConnections::FetchCachedHomeContent.invalidate(server_connection) if has_stopped
      end

      Result.new(success?: true, synced_count: synced, access_token: current_token, message: nil)
    rescue BatchReportError => error
      Result.new(success?: false, synced_count: 0, access_token: current_token, message: error.message)
    end

    private

    attr_reader :server_connection, :events, :user, :access_token, :client

    def normalize_event(event)
      h = event.is_a?(Hash) ? event.with_indifferent_access : {}
      {
        event: h[:event].to_s,
        item_id: (h[:item_id] || h[:itemId]).to_s,
        position_ticks: (h[:position_ticks] || h[:positionTicks]).to_i,
        duration_ticks: (h[:duration_ticks] || h[:durationTicks]).to_i,
        paused: ActiveModel::Type::Boolean.new.cast(h[:paused]),
        resumable: ActiveModel::Type::Boolean.new.cast(h[:resumable]),
        occurred_at: parse_time(h[:occurred_at] || h[:occurredAt])
      }
    end

    def parse_time(value)
      return Time.current if value.blank?

      parsed = value.is_a?(Time) ? value : Time.zone.parse(value.to_s)
      parsed || Time.current
    rescue StandardError
      Time.current
    end

    def create_listening_event_if_missing(ev)
      time = ev[:occurred_at]
      existing = user.listening_events.exists?(
        server_connection: server_connection,
        item_id: ev[:item_id],
        occurred_at: time
      )
      return if existing

      user.listening_events.create!(
        server_connection: server_connection,
        item_id: ev[:item_id],
        occurred_at: time
      )
    end
  end
end
