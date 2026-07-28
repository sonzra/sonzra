class ArtworkController < ApplicationController
  def show
    server_connection = current_user.server_connections.find(params.expect(:server_connection_id))
    access_token = session.dig(:server_access_tokens, server_connection.id.to_s)
    return head :unauthorized unless access_token

    artwork = Integrations::Jellyfin::Client.new(
      base_url: server_connection.base_url,
      username: server_connection.username,
      password: server_connection.password
    ).artwork(item_id: params.expect(:item_id), tag: params[:tag], access_token: access_token)

    send_data artwork.body, type: artwork.content_type, disposition: "inline"
  rescue Integrations::Jellyfin::Client::ConnectionError
    head :bad_gateway
  end
end
