class LyricsController < ApplicationController
  def show
    server_connection = current_user.server_connections.find(params.expect(:server_connection_id))
    result = ServerConnections::FetchLyrics.new(
      server_connection,
      params.expect(:item_id),
      remote_user_id: session.dig(:server_remote_user_ids, server_connection.id.to_s),
      access_token: server_access_token(server_connection),
      device_id: current_device_id
    ).call
    return render json: { error: result.message }, status: :bad_gateway unless result.success?

    store_server_access_token(server_connection, result.access_token)
    render json: { available: result.available, synchronized: result.synchronized, lines: result.lines }
  end
end
