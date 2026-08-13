class HiddenArtistsController < ApplicationController
  def index
    @hidden_artists = current_user.hidden_artists.includes(:server_connection).order(:name)
  end

  def create
    connection = current_user.server_connections.find(params.expect(:server_connection_id))
    current_user.hidden_artists.find_or_create_by!(server_connection: connection, artist_id: params.expect(:artist_id)) do |artist|
      artist.name = params.expect(:name)
    end
    respond_to do |format|
      format.html { redirect_back fallback_location: library_artists_path, notice: "Artist hidden." }
      format.json { head :created }
    end
  end

  def destroy
    current_user.hidden_artists.find(params.expect(:id)).destroy!
    redirect_back fallback_location: hidden_artists_path, notice: "Artist restored."
  end
end
