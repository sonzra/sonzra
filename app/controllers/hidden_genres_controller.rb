class HiddenGenresController < ApplicationController
  def index
    @hidden_genres = current_user.hidden_genres.includes(:server_connection).order(:name)
    @server_connections = current_user.server_connections.includes(:media_server).order(:created_at)
  end

  def create
    connection = current_user.server_connections.find(params.expect(:server_connection_id))
    current_user.hidden_genres.find_or_create_by!(server_connection: connection, name: params.expect(:name))

    respond_to do |format|
      format.html { redirect_back fallback_location: hidden_genres_path, notice: "Genre hidden." }
      format.json { head :created }
    end
  end

  def destroy
    current_user.hidden_genres.find(params.expect(:id)).destroy!
    redirect_back fallback_location: hidden_genres_path, notice: "Genre restored."
  end
end
