class LibraryItemsController < ApplicationController
  def show
    @server_connection = current_user.server_connections.find(params.expect(:server_connection_id))
    @result = ServerConnections::FetchLibraryItemDetails.new(@server_connection, params.expect(:id)).call
    session[:server_access_tokens] = session.fetch(:server_access_tokens, {}).merge(@server_connection.id.to_s => @result.access_token) if @result.success?
  end
end
