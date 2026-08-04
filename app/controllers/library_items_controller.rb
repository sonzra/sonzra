class LibraryItemsController < ApplicationController
  def show
    @server_connection = current_user.server_connections.find(params.expect(:server_connection_id))
    @result = ServerConnections::FetchLibraryItemDetails.new(@server_connection, params.expect(:id)).call
    return unless @result.success?

    session[:server_access_tokens] = session.fetch(:server_access_tokens, {}).merge(@server_connection.id.to_s => @result.access_token)
    @back_path, @back_label = detail_back_destination(@result.details)
    @media_detail_header = playable_media_detail?(@result.details)
    @media_detail_title = media_detail_title(@result.details) if @media_detail_header
  end

  private

  def detail_back_destination(details)
    item = details.fetch(:item)
    kind = details.fetch(:kind, :music)
    return [ library_audiobooks_path, "Audiobooks" ] if kind == :audiobook
    return [ library_podcasts_path, "Podcasts" ] if kind == :podcast
    return [ library_playlists_path, "Playlists" ] if kind == :playlist || item["Type"] == "Playlist"
    return [ library_artists_path, "Artists" ] if item["Type"] == "MusicArtist"

    [ library_albums_path, "Albums" ]
  end

  def playable_media_detail?(details)
    details.fetch(:kind, :music).in?([ :audiobook, :podcast, :playlist ]) || details.fetch(:item).fetch("Type").in?([ "Audio", "MusicAlbum", "MusicArtist", "Playlist" ])
  end

  def media_detail_title(details)
    item = details.fetch(:item)
    return item["Album"].presence || item["AlbumArtist"].presence || item.fetch("Name") if details.fetch(:kind, :music) == :podcast
    return item.fetch("Name") if item["Type"] == "MusicArtist"

    details.fetch(:album).fetch("Name")
  end
end
