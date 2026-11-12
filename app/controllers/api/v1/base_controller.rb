module Api
  module V1
    class BaseController < ApplicationController
      skip_before_action :verify_authenticity_token
      allow_unauthenticated_access only: :cors_preflight
      before_action :set_cors_headers

      def cors_preflight
        head :ok
      end

      rescue_from ActionController::ParameterMissing do |exception|
        render json: { error: exception.message }, status: :unprocessable_entity
      end

      private

      def set_cors_headers
        headers["Access-Control-Allow-Origin"] = "*"
        headers["Access-Control-Allow-Methods"] = "GET, POST, PUT, PATCH, DELETE, OPTIONS"
        headers["Access-Control-Allow-Headers"] = "Content-Type, Authorization, Accept, X-Requested-With, X-Device-ID"
        headers["Access-Control-Max-Age"] = "86400"
      end

      def current_connection
        @current_connection ||= if params[:server_connection_id].present?
          current_user.server_connections.find_by(id: params[:server_connection_id])
        else
          current_server_connection
        end
      end

      def client_device_id
        request.headers["X-Device-ID"].presence || params[:device_id].presence || current_device_id
      end

      def render_service_error(result)
        if result.message.to_s.match?(/session expired|401|authentication/i)
          record_connection_alert(current_connection)
          render json: { error: result.message }, status: :unauthorized
        else
          render json: { error: result.message.presence || "Operation failed" }, status: :bad_gateway
        end
      end

      def audio_stream_url(connection, item_id)
        "/server_connections/#{connection.id}/audio/#{item_id}"
      end

      def artwork_url_for(connection, item_id)
        "/server_connections/#{connection.id}/artwork/#{item_id}"
      end
    end
  end
end
