module Api
  module V1
    class PlaybackReportsController < BaseController
      MAX_BATCH_SIZE = 100

      def create
        return render json: { error: "No server connection found" }, status: :unprocessable_entity unless current_connection

        if params[:events].present? || params[:_json].present?
          return handle_batch
        end

        event = normalized_event
        unless ServerConnections::ReportPlayback::EVENTS.include?(event)
          return render json: { error: "Invalid playback event: #{params[:event]}" }, status: :unprocessable_entity
        end

        item_id = params.expect(:item_id)
        position_ticks = parse_position_ticks
        duration_ticks = parse_duration_ticks
        paused = parse_paused(event)
        resumable = ActiveModel::Type::Boolean.new.cast(params[:resumable])

        result = ServerConnections::ReportPlayback.new(
          current_connection,
          event: event,
          item_id: item_id,
          position_ticks: position_ticks,
          paused: paused,
          duration_ticks: duration_ticks,
          resumable: resumable,
          access_token: server_access_token(current_connection),
          device_id: client_device_id
        ).call

        return render json: { error: result.message }, status: :bad_gateway unless result.success?

        store_server_access_token(current_connection, result.access_token)
        current_user.listening_events.create!(server_connection: current_connection, item_id: item_id, occurred_at: Time.current) if event == "started"
        ServerConnections::FetchCachedHomeContent.invalidate(current_connection) if event == "stopped"

        render json: { status: "ok" }, status: :ok
      end

      private

      def handle_batch
        events_data = params[:events] || params[:_json] || []
        events_data = events_data.map { |e| e.respond_to?(:to_unsafe_h) ? e.to_unsafe_h : e } if events_data.respond_to?(:map)

        return render json: { error: "Batch size exceeds limit" }, status: :unprocessable_entity if events_data.size > MAX_BATCH_SIZE

        result = ServerConnections::ReportPlaybackBatch.new(
          current_connection,
          events: events_data,
          user: current_user,
          access_token: server_access_token(current_connection),
          device_id: client_device_id
        ).call

        return render json: { error: result.message }, status: :bad_gateway unless result.success?

        store_server_access_token(current_connection, result.access_token)

        render json: { status: "ok", count: events_data.size }, status: :ok
      end

      def normalized_event
        ev = params[:event].to_s.downcase
        return "stopped" if ev == "completed"
        return "progress" if ev == "paused"

        ev
      end

      def parse_position_ticks
        if params[:position_ticks].present?
          params[:position_ticks].to_i
        elsif params[:position_seconds].present?
          (params[:position_seconds].to_f * 10_000_000).to_i
        else
          0
        end
      end

      def parse_duration_ticks
        if params[:duration_ticks].present?
          params[:duration_ticks].to_i
        elsif params[:duration_seconds].present?
          (params[:duration_seconds].to_f * 10_000_000).to_i
        else
          0
        end
      end

      def parse_paused(event)
        if params.key?(:paused)
          ActiveModel::Type::Boolean.new.cast(params[:paused])
        else
          params[:event].to_s.downcase == "paused"
        end
      end
    end
  end
end
