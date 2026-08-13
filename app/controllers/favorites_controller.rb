class FavoritesController < ApplicationController
  def update
    favorite = ActiveModel::Type::Boolean.new.cast(params.expect(:favorite))
    Integrations::Client.for(server_connection).update_favorite(item_id: params.expect(:item_id), favorite: favorite)
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
