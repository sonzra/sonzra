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

  def genres
    @title = "Genres"
    @server_connection = current_user.server_connections.order(:created_at).first
    return render :no_server unless @server_connection

    @query = params[:q].presence
    @result = ServerConnections::FetchLibraryCollection.new(@server_connection, :genres, page: 1, query: @query).call
  end

  private

  def render_collection(collection, title)
    @title = title
    @collection = collection
    @server_connection = current_user.server_connections.order(:created_at).first
    return render :no_server unless @server_connection

    @page = [ params[:page].to_i, 1 ].max
    @query = params[:q].presence
    @genre = params[:genre].presence
    @title = "#{title} in #{@genre}" if @genre
    @result = ServerConnections::FetchLibraryCollection.new(@server_connection, collection, page: @page, query: @query, genre: @genre).call
    session[:server_access_tokens] = session.fetch(:server_access_tokens, {}).merge(@server_connection.id.to_s => @result.access_token) if @result.success?
  end
end
