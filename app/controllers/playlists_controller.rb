class PlaylistsController < ApplicationController
  def index
    render json: client.playlists
    cache_remote_user_id
  rescue Integrations::AuthenticationError, Integrations::ConnectionError => error
    render json: { error: error.message }, status: :bad_gateway
  end

  def create
    playlist_id = if server_connection.media_server.plex?
      client.create_playlist(params.expect(:name), item_ids: playlist_item_ids)
    else
      client.create_playlist(params.expect(:name))
    end

    render json: { id: playlist_id, item_included: server_connection.media_server.plex? }, status: :created
    cache_remote_user_id
  rescue Integrations::AuthenticationError, Integrations::ConnectionError => error
    render json: { error: error.message }, status: :bad_gateway
  end

  def add_item
    client.add_to_playlist(
      playlist_id: params.expect(:playlist_id),
      item_ids: playlist_item_ids
    )
    cache_remote_user_id
    broadcast_track_addition(params[:playlist_id], playlist_item_ids)
    head :no_content
  rescue Integrations::AuthenticationError, Integrations::ConnectionError => error
    render json: { error: error.message }, status: :bad_gateway
  end

  def destroy
    if client.respond_to?(:supports?) && client.supports?(Integrations::Capabilities::COLLABORATIVE_PLAYLISTS)
      users_result = ServerConnections::CollaborativePlaylists::FetchPlaylistUsers.new(
        server_connection,
        playlist_id: params.expect(:id),
        client: client
      ).call

      unless users_result.success?
        if users_result.message.to_s.include?("403") || users_result.message.to_s.include?("404")
          render json: { error: "Collaborators cannot delete shared playlists." }, status: :forbidden
        else
          render json: { error: users_result.message }, status: :bad_gateway
        end
        return
      end

      collaborators = (users_result.users || []).reject do |u|
        (u["UserId"] || u["Id"]) == server_connection.remote_user_id
      end

      if collaborators.any?
        render json: { error: "Cannot delete a playlist while it is shared with other listeners. Remove collaborators first." }, status: :unprocessable_entity
        return
      end
    end

    client.delete_playlist(playlist_id: params.expect(:id))
    cache_remote_user_id
    head :no_content
  rescue Integrations::AuthenticationError, Integrations::ConnectionError => error
    render json: { error: delete_error_message(error) }, status: :bad_gateway
  end

  def remove_item
    client.remove_from_playlist(playlist_id: params.expect(:playlist_id), entry_id: params.expect(:entry_id))
    cache_remote_user_id
    broadcast_track_removal(params[:playlist_id], params[:entry_id])
    head :no_content
  rescue Integrations::AuthenticationError, Integrations::ConnectionError => error
    render json: { error: error.message }, status: :bad_gateway
  end

  private

  def server_connection
    @server_connection ||= current_user.server_connections.find(params.expect(:server_connection_id))
  end

  def client
    @client ||= Integrations::Client.for(
      server_connection,
      remote_user_id: session_remote_user_id,
      access_token: server_access_token(server_connection),
      device_id: current_device_id
    )
  end

  def cache_remote_user_id
    return unless client.respond_to?(:resolved_user_id)
    return if client.resolved_user_id.blank?

    session[:server_remote_user_ids] = session.fetch(:server_remote_user_ids, {}).merge(server_connection.id.to_s => client.resolved_user_id)
  end

  def session_remote_user_id
    session.dig(:server_remote_user_ids, server_connection.id.to_s)
  end

  def delete_error_message(error)
    return error.message unless error.message.start_with?("The server returned HTTP")

    "The server couldn’t delete this playlist. Some playlists are managed outside Sonzra and can only be removed directly in their server app."
  end

  def playlist_item_ids
    case params[:item_type]
    when "MusicAlbum"
      client.playback_queue(params.expect(:item_id)).items.pluck("Id")
    when "MusicArtist"
      client.artist_track_ids(params.expect(:item_id))
    when "RecommendationCollection"
      current_user.recommendation_collections.find(params.expect(:item_id)).recommendation_tracks.map(&:item_id)
    else
      [ params.expect(:item_id) ]
    end
  end

  def broadcast_track_addition(playlist_id, item_ids)
    return unless client.supports?(Integrations::Capabilities::COLLABORATIVE_PLAYLISTS)

    details = client.library_item_details(playlist_id).details
    album = details.fetch(:album)
    tracks = details.fetch(:tracks, [])
    added_tracks = tracks.select { |t| item_ids.include?(t["Id"]) }

    added_tracks.each do |track|
      Turbo::StreamsChannel.broadcast_append_to(
        "playlist_#{server_connection.media_server_id}_#{playlist_id}",
        target: "playlist_tracks_#{playlist_id}",
        partial: "library_items/playlist_track",
        locals: {
          track: track,
          album: album,
          server_connection: server_connection
        }
      )
    end
  rescue StandardError => e
    Rails.logger.warn("Live sync broadcast addition error: #{e.message}")
  end

  def broadcast_track_removal(playlist_id, entry_id)
    return unless client.supports?(Integrations::Capabilities::COLLABORATIVE_PLAYLISTS)

    Turbo::StreamsChannel.broadcast_remove_to(
      "playlist_#{server_connection.media_server_id}_#{playlist_id}",
      target: "playlist_entry_#{entry_id}"
    )
  rescue StandardError => e
    Rails.logger.warn("Live sync broadcast removal error: #{e.message}")
  end
end
