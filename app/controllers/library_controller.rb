class LibraryController < ApplicationController
  def artists
    render_collection(:artists, "Artists")
  end

  def albums
    render_collection(:albums, "Albums")
  end

  def audiobooks
    render_collection(:audiobooks, "Audiobooks")
  end

  def podcasts
    render_collection(:podcasts, "Podcasts")
  end

  def playlists
    render_collection(:playlists, "Playlists")
  end

  def recently_played
    render_collection(:recently_played, "Recently played")
  end

  def most_played_songs
    render_collection(:most_played_songs, "Most played songs")
  end

  def recently_added_albums
    render_collection(:recently_added_albums, "Recently added albums")
  end

  def genres
    @title = "Genres"
    @server_connection = current_server_connection
    return render :no_server unless @server_connection

    @query = params[:q].presence
    @result = ServerConnections::FetchLibraryCollection.new(@server_connection, :genres, user: current_user, page: 1, query: @query).call
  end

  private

  def render_collection(collection, title)
    @title = title
    @collection = collection
    @server_connection = current_server_connection
    return render :no_server unless @server_connection

    @page = [ params[:page].to_i, 1 ].max
    @letter = params[:letter].presence
    @query = params[:q].presence
    @genre = params[:genre].presence
    @title = "#{title} in #{@genre}" if @genre

    @service = ServerConnections::FetchLibraryCollection.new(
      @server_connection, collection,
      user: current_user, page: @page, query: @query, genre: @genre, letter: @letter
    )
    @result = @service.call
    @supports_letter_filtering = @service.supports?(Integrations::Capabilities::LETTER_FILTERING)

    session[:server_access_tokens] = session.fetch(:server_access_tokens, {}).merge(@server_connection.id.to_s => @result.access_token) if @result.success?

    respond_to do |format|
      format.html
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.append("library-grid", partial: "library/grid_items", locals: { items: @result.items, server_connection: @server_connection, collection: @collection }),
          turbo_stream.replace("library-scroll-state", partial: "library/scroll_state", locals: { has_more: @result.has_more, page: @page, letter: @letter })
        ]
      end
    end
  end
end
