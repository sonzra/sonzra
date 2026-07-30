class ResumeItemsController < ApplicationController
  def reset
    result = ServerConnections::ResetPlaybackPosition.new(
      server_connection,
      item_id: params.expect(:item_id),
      access_token: session.dig(:server_access_tokens, server_connection.id.to_s)
    ).call
    return render json: { error: result.message }, status: :bad_gateway unless result.success?

    session[:server_access_tokens] = session.fetch(:server_access_tokens, {}).merge(server_connection.id.to_s => result.access_token)
    ServerConnections::FetchCachedHomeContent.invalidate(server_connection)
    head :no_content
  end

  private

  def server_connection
    @server_connection ||= current_user.server_connections.find(params.expect(:server_connection_id))
  end
end
