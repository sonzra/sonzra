class LibraryItemsController < ApplicationController
  def show
    @server_connection = current_user.server_connections.find(params.expect(:server_connection_id))
    @result = ServerConnections::FetchLibraryItemDetails.new(
      @server_connection,
      params.expect(:id),
      user: current_user,
      access_token: server_access_token(@server_connection),
      device_id: current_device_id
    ).call
    if @result.success?
      clear_connection_alert(@server_connection)
      store_server_access_token(@server_connection, @result.access_token)
      @back_path, @back_label = detail_back_destination(@result.details)
      @media_detail_header = playable_media_detail?(@result.details)
      @media_detail_title = media_detail_title(@result.details) if @media_detail_header
      load_collaborative_playlist_details if @result.details.fetch(:kind, :music) == :playlist
    elsif @result.message.to_s.match?(/session expired|401|authentication/i)
      record_connection_alert(@server_connection)
    end
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

  def load_collaborative_playlist_details
    client = Integrations::Client.for(
      @server_connection,
      access_token: @result.access_token,
      device_id: current_device_id
    )
    @collaborative_supported = client.supports?(Integrations::Capabilities::COLLABORATIVE_PLAYLISTS)
    return unless @collaborative_supported

    playlist_id = @result.details.fetch(:album).fetch("Id")
    users_result = ServerConnections::CollaborativePlaylists::FetchPlaylistUsers.new(
      @server_connection,
      playlist_id: playlist_id,
      client: client
    ).call
    remote_users = users_result.success? ? (users_result.users || []) : []
    remote_ids = remote_users.map { |u| u["UserId"] || u["Id"] }.compact
    @fellow_connections = @server_connection.fellow_instance_connections
    @collaborators = @fellow_connections.select { |conn| conn.remote_user_id.present? && remote_ids.include?(conn.remote_user_id) }
  rescue StandardError => e
    Rails.logger.warn("Could not load playlist collaborators: #{e.message}")
    @collaborators = []
  end
end
