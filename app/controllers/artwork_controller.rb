class ArtworkController < ApplicationController
  def show
    server_connection = current_user.server_connections.find(params.expect(:server_connection_id))
    access_token = session.dig(:server_access_tokens, server_connection.id.to_s)
    return send_fallback_artwork unless access_token

    artwork = Integrations::Client.for(server_connection).artwork(
      item_id: params.expect(:item_id),
      tag: params[:tag],
      access_token: access_token
    )

    if params[:tag].present?
      expires_in 1.year, immutable: true
    else
      expires_in 5.minutes
    end
    send_data artwork.body, type: artwork.content_type, disposition: "inline"
  rescue StandardError => e
    Rails.logger.warn("[ArtworkController] Failed to fetch artwork for item #{params[:item_id]}: #{e.message}")
    send_fallback_artwork
  end

  private

  def send_fallback_artwork
    expires_in 1.hour
    send_file Rails.root.join("app/assets/images/brand/sonzra-mark.svg"), type: "image/svg+xml", disposition: "inline"
  end
end
