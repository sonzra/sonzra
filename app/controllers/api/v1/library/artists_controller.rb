module Api
  module V1
    module Library
      class ArtistsController < BaseController
        def index
          return render json: { error: "No server connection found" }, status: :unprocessable_entity unless current_connection

          page = [ params[:page].to_i, 1 ].max
          service = ServerConnections::FetchLibraryCollection.new(
            current_connection,
            :artists,
            user: current_user,
            page: page,
            query: params[:q].presence,
            letter: params[:letter].presence,
            access_token: server_access_token(current_connection),
            device_id: client_device_id
          )
          result = service.call

          return render_service_error(result) unless result.success?

          store_server_access_token(current_connection, result.access_token)
          clear_connection_alert(current_connection)

          artists = result.items.map do |item|
            {
              id: item["Id"].to_s,
              name: item["Name"],
              artwork_url: artwork_url_for(current_connection, item["Id"]),
              server_connection_id: current_connection.id
            }
          end

          render json: artists
        end
      end
    end
  end
end
