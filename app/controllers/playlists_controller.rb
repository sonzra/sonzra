class PlaylistsController < ApplicationController
  def index
    render json: client.playlists
    cache_remote_user_id
  rescue Integrations::Jellyfin::Client::AuthenticationError, Integrations::Jellyfin::Client::ConnectionError => error
    render json: { error: error.message }, status: :bad_gateway
  end

  def create
    render json: { id: client.create_playlist(params.expect(:name)) }, status: :created
    cache_remote_user_id
  rescue Integrations::Jellyfin::Client::AuthenticationError, Integrations::Jellyfin::Client::ConnectionError => error
    render json: { error: error.message }, status: :bad_gateway
  end

  def add_item
    client.add_to_playlist(
      playlist_id: params.expect(:playlist_id),
      item_ids: playlist_item_ids
    )
    cache_remote_user_id
    head :no_content
  rescue Integrations::Jellyfin::Client::AuthenticationError, Integrations::Jellyfin::Client::ConnectionError => error
    render json: { error: error.message }, status: :bad_gateway
  end

  def destroy
    client.delete_playlist(playlist_id: params.expect(:id))
    cache_remote_user_id
    head :no_content
  rescue Integrations::Jellyfin::Client::AuthenticationError, Integrations::Jellyfin::Client::ConnectionError => error
    render json: { error: delete_error_message(error) }, status: :bad_gateway
  end

  def remove_item
    client.remove_from_playlist(playlist_id: params.expect(:playlist_id), entry_id: params.expect(:entry_id))
    cache_remote_user_id
    head :no_content
  rescue Integrations::Jellyfin::Client::AuthenticationError, Integrations::Jellyfin::Client::ConnectionError => error
    render json: { error: error.message }, status: :bad_gateway
  end

  private

  def server_connection
    @server_connection ||= current_user.server_connections.find(params.expect(:server_connection_id))
  end

  def client
    @client ||= Integrations::Jellyfin::Client.new(**server_connection.client_options(remote_user_id: session_remote_user_id))
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

    "Jellyfin couldn’t delete this playlist. Some playlists are managed outside Sonzra and can only be removed directly in Jellyfin."
  end

  def playlist_item_ids
    return [ params.expect(:item_id) ] unless params[:item_type] == "MusicAlbum"

    client.playback_queue(params.expect(:item_id)).items.pluck("Id")
  end
end
