class PlaybackController < ApplicationController
  include ActionController::Live
  allow_unauthenticated_access only: %i[show cors_preflight]

  before_action :set_cors_headers
  before_action :require_playback_access, except: :cors_preflight

  def cors_preflight
    head :ok
  end

  def show
    token = analyzer_request? ? server_connection.access_token : server_access_token(server_connection)
    client.stream_audio(
      item_id: params.expect(:item_id),
      range: request.headers["Range"],
      access_token: token
    ) do |part|
      part.is_a?(Integrations::AudioStreamResponseData) ? start_stream(part) : response.stream.write(part)
    end
  rescue Integrations::AuthenticationError
    head :unauthorized
  rescue Integrations::ConnectionError
    head :bad_gateway
  rescue ActionController::Live::ClientDisconnected
  ensure
    response.stream.close
  end

  private

  def set_cors_headers
    headers["Access-Control-Allow-Origin"] = "*"
    headers["Access-Control-Allow-Methods"] = "GET, OPTIONS"
    headers["Access-Control-Allow-Headers"] = "Range, Content-Type, Authorization, Accept, X-Requested-With, X-Device-ID"
    headers["Access-Control-Expose-Headers"] = "Content-Range, Accept-Ranges, Content-Length"
    headers["Access-Control-Max-Age"] = "86400"
  end

  def client
    token = analyzer_request? ? server_connection.access_token : (server_access_token(server_connection) || server_connection.access_token)
    device_id = analyzer_request? ? "sonzra-analyzer-#{server_connection.id}" : current_device_id
    @client ||= Integrations::Client.for(server_connection, access_token: token, device_id: device_id)
  end

  def server_connection
    @server_connection ||= analyzer_request? ? ServerConnection.find(params.expect(:server_connection_id)) : current_user.server_connections.find(params.expect(:server_connection_id))
  end

  def require_playback_access
    if analyzer_request?
      head :unauthorized unless valid_analyzer_token?
      return
    end

    return if authenticated?

    request_authentication
  end

  def analyzer_request?
    request.headers["X-Sonzra-Analyzer-Token"].present?
  end

  def valid_analyzer_token?
    expected_token = if Rails.env.production?
      ENV["ANALYZER_API_KEY"].presence
    else
      ENV["ANALYZER_API_KEY"].presence || "development_analyzer_token"
    end

    return false if expected_token.blank?

    ActiveSupport::SecurityUtils.secure_compare(request.headers["X-Sonzra-Analyzer-Token"].to_s, expected_token)
  end

  def start_stream(stream)
    response.status = stream.status
    response.content_type = stream.content_type
    response.headers["Accept-Ranges"] = stream.accept_ranges if stream.accept_ranges.present?
    response.headers["Content-Range"] = stream.content_range if stream.content_range.present?
    response.headers["Content-Length"] = stream.content_length if stream.content_length.present?
  end
end
