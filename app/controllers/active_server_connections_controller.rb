class ActiveServerConnectionsController < ApplicationController
  def update
    connection = current_user.server_connections.find(params.expect(:server_connection_id))
    current_user.update!(preferred_server_connection: connection)
    session[:active_server_connection_id] = connection.id
    ServerConnections::FetchCachedHomeContent.invalidate(connection)
    redirect_back fallback_location: root_path, notice: "Using #{connection.name}."
  end
end
