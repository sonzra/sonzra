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
    @query = params[:q].presence
    @genre = params[:genre].presence
    @title = "#{title} in #{@genre}" if @genre
    @result = ServerConnections::FetchLibraryCollection.new(@server_connection, collection, user: current_user, page: @page, query: @query, genre: @genre).call
    session[:server_access_tokens] = session.fetch(:server_access_tokens, {}).merge(@server_connection.id.to_s => @result.access_token) if @result.success?
  end
end
