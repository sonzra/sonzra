class PlaybackReportsController < ApplicationController
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
      access_token: session.dig(:server_access_tokens, server_connection.id.to_s)
    ).call
    return render json: { error: result.message }, status: :bad_gateway unless result.success?

    session[:server_access_tokens] = session.fetch(:server_access_tokens, {}).merge(server_connection.id.to_s => result.access_token)
    current_user.listening_events.create!(server_connection:, item_id: params.expect(:item_id), occurred_at: Time.current) if event == "started"
    ServerConnections::FetchCachedHomeContent.invalidate(server_connection) if event == "stopped"
    head :no_content
  end

  def batch
    events_data = params[:events] || params[:_json] || []
    events_data = events_data.map { |e| e.respond_to?(:to_unsafe_h) ? e.to_unsafe_h : e } if events_data.respond_to?(:map)

    result = ServerConnections::ReportPlaybackBatch.new(
      server_connection,
      events: events_data,
      user: current_user,
      access_token: session.dig(:server_access_tokens, server_connection.id.to_s)
    ).call

    return render json: { error: result.message }, status: :bad_gateway unless result.success?

    if result.access_token.present?
      session[:server_access_tokens] = session.fetch(:server_access_tokens, {}).merge(server_connection.id.to_s => result.access_token)
    end

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
