class HiddenGenresController < ApplicationController
  def index
    @hidden_genres = current_user.hidden_genres.includes(:server_connection).order(:name)
    @server_connections = current_user.server_connections.includes(:media_server).order(:created_at)
  end

  def create
    connection = current_user.server_connections.find(params.expect(:server_connection_id))
    @hidden_genre = current_user.hidden_genres.find_or_create_by!(server_connection: connection, name: params.expect(:name))

    respond_to do |format|
      format.turbo_stream do
        streams = []
        dom_tile_id = "genre_tile_#{@hidden_genre.name.parameterize}"
        streams << turbo_stream.remove(dom_tile_id)
        if current_user.hidden_genres.count == 1
          streams << turbo_stream.update("hidden_genres_container", %(<section id="hidden_genres_list" class="connection-list">#{render_to_string(partial: "hidden_genres/hidden_genre", locals: { genre: @hidden_genre })}</section>))
        else
          streams << turbo_stream.remove("hidden_genres_empty")
          streams << turbo_stream.append("hidden_genres_list", partial: "hidden_genres/hidden_genre", locals: { genre: @hidden_genre })
        end
        render turbo_stream: streams
      end
      format.html { redirect_back fallback_location: hidden_genres_path, notice: "Genre hidden." }
      format.json { head :created }
    end
  end

  def destroy
    @hidden_genre = current_user.hidden_genres.find(params.expect(:id))
    @hidden_genre.destroy!

    respond_to do |format|
      format.turbo_stream do
        streams = [ turbo_stream.remove(helpers.dom_id(@hidden_genre)) ]
        if current_user.hidden_genres.none?
          streams << turbo_stream.update("hidden_genres_container", render_to_string(partial: "hidden_genres/empty_state"))
        end
        render turbo_stream: streams
      end
      format.html { redirect_back fallback_location: hidden_genres_path, notice: "Genre restored." }
      format.json { head :no_content }
    end
  end
end
