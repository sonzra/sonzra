class PlaybackReportsController < ApplicationController
  MAX_BATCH_SIZE = 100

  def create
    return head :unprocessable_entity unless ServerConnections::ReportPlayback::EVENTS.include?(event)

    result = ServerConnections::ReportPlayback.new(
      server_connection,
      event: event,
      item_id: params.expect(:item_id),
      position_ticks: params.expect(:position_ticks).to_i,
      paused: ActiveModel::Type::Boolean.new.cast(params.expect(:paused)),
      duration_ticks: params[:duration_ticks].to_i,
      resumable: ActiveModel::Type::Boolean.new.cast(params[:resumable]),
      access_token: server_access_token(server_connection),
      device_id: current_device_id
    ).call
    return render json: { error: result.message }, status: :bad_gateway unless result.success?

    store_server_access_token(server_connection, result.access_token)
    current_user.listening_events.create!(server_connection:, item_id: params.expect(:item_id), occurred_at: Time.current) if event == "started"
    ServerConnections::FetchCachedHomeContent.invalidate(server_connection) if event == "stopped"
    head :no_content
  end

  def batch
    events_data = params[:events] || params[:_json] || []
    events_data = events_data.map { |e| e.respond_to?(:to_unsafe_h) ? e.to_unsafe_h : e } if events_data.respond_to?(:map)

    return head :unprocessable_entity if events_data.size > MAX_BATCH_SIZE

    result = ServerConnections::ReportPlaybackBatch.new(
      server_connection,
      events: events_data,
      user: current_user,
      access_token: server_access_token(server_connection),
      device_id: current_device_id
    ).call

    return render json: { error: result.message }, status: :bad_gateway unless result.success?

    store_server_access_token(server_connection, result.access_token)

    head :no_content
  end

  private

  def event
    params.expect(:event)
  end

  def server_connection
    @server_connection ||= current_user.server_connections.find(params.expect(:server_connection_id))
  end
end
