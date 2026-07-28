class PlaybackController < ApplicationController
  include ActionController::Live

  def show
    client.stream_audio(
      item_id: params.expect(:item_id),
      range: request.headers["Range"],
      access_token: session.dig(:server_access_tokens, server_connection.id.to_s)
    ) do |part|
      part.is_a?(Integrations::Jellyfin::AudioStreamResponseData) ? start_stream(part) : response.stream.write(part)
    end
  rescue Integrations::Jellyfin::Client::AuthenticationError
    head :unauthorized
  rescue Integrations::Jellyfin::Client::ConnectionError
    head :bad_gateway
  ensure
    response.stream.close
  end

  private

  def client
    @client ||= Integrations::Jellyfin::Client.new(
      base_url: server_connection.base_url,
      username: server_connection.username,
      password: server_connection.password
    )
  end

  def server_connection
    @server_connection ||= current_user.server_connections.find(params.expect(:server_connection_id))
  end

  def start_stream(stream)
    response.status = stream.status
    response.content_type = stream.content_type
    response.headers["Accept-Ranges"] = stream.accept_ranges if stream.accept_ranges.present?
    response.headers["Content-Range"] = stream.content_range if stream.content_range.present?
    response.headers["Content-Length"] = stream.content_length if stream.content_length.present?
  end
end
