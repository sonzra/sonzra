class FavoritesController < ApplicationController
  def update
    favorite = ActiveModel::Type::Boolean.new.cast(params.expect(:favorite))
    client = Integrations::Client.for(
      server_connection,
      access_token: server_access_token(server_connection),
      device_id: current_device_id
    )
    client.update_favorite(item_id: params.expect(:item_id), favorite: favorite)
    store_server_access_token(server_connection, client.access_token) if client.respond_to?(:access_token)
    ServerConnections::FetchCachedHomeContent.invalidate(server_connection)
    render json: { favorite: favorite }
  rescue Integrations::Jellyfin::Client::AuthenticationError, Integrations::Jellyfin::Client::ConnectionError => error
    render json: { error: error.message }, status: :bad_gateway
  end

  private

  def server_connection
    @server_connection ||= current_user.server_connections.find(params.expect(:server_connection_id))
  end
end
