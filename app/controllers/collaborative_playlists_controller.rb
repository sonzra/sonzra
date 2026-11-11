# frozen_string_literal: true

class CollaborativePlaylistsController < ApplicationController
  before_action :set_server_connection
  before_action :verify_collaborative_capability

  def index
    @playlist_id = params.expect(:playlist_id)
    @playlist_name = params[:playlist_name]
    @result = ServerConnections::CollaborativePlaylists::FetchPlaylistUsers.new(
      @server_connection,
      playlist_id: @playlist_id,
      client: client
    ).call

    @remote_users = @result.success? ? (@result.users || []) : []
    remote_ids = @remote_users.map { |u| u["UserId"] || u["Id"] }.compact
    @fellow_connections = @server_connection.fellow_instance_connections

    respond_to do |format|
      format.json do
        render json: {
          fellow_connections: @fellow_connections.map do |conn|
            {
              id: conn.id,
              username: conn.username,
              email: conn.user.email_address,
              display_name: conn.user.email_address.split("@").first,
              is_collaborator: conn.remote_user_id.present? && remote_ids.include?(conn.remote_user_id)
            }
          end
        }
      end
      format.html { render partial: "dialog_content" }
    end
  end

  def create
    target_connection = @server_connection.fellow_instance_connections.find(params.expect(:target_connection_id))
    result = ServerConnections::CollaborativePlaylists::SharePlaylist.new(
      @server_connection,
      target_connection,
      playlist_id: params.expect(:playlist_id),
      client: client
    ).call

    if result.success?
      playlist_name = params[:playlist_name].presence || "a playlist"
      Notifications::DeliverNotification.new(
        target_connection.user,
        title: "Playlist Shared",
        message: "#{current_user.email_address.split('@').first} shared the playlist \"#{playlist_name}\" with you.",
        link_url: library_item_server_connection_path(target_connection, params[:playlist_id]),
        actor_user: current_user
      ).call

      render json: { success: true }, status: :ok
    else
      render json: { error: result.message }, status: :unprocessable_entity
    end
  end

  def destroy
    target_connection = @server_connection.fellow_instance_connections.find(params.expect(:target_connection_id))
    result = ServerConnections::CollaborativePlaylists::UnsharePlaylist.new(
      @server_connection,
      target_connection,
      playlist_id: params.expect(:playlist_id),
      client: client
    ).call

    if result.success?
      render json: { success: true }, status: :ok
    else
      render json: { error: result.message }, status: :unprocessable_entity
    end
  end

  private

  def set_server_connection
    @server_connection = current_user.server_connections.find(params.expect(:server_connection_id))
  end

  def client
    @client ||= Integrations::Client.for(
      @server_connection,
      access_token: server_access_token(@server_connection),
      device_id: current_device_id
    )
  end

  def verify_collaborative_capability
    return if client.supports?(Integrations::Capabilities::COLLABORATIVE_PLAYLISTS)

    render json: { error: "Collaborative playlists are not supported by this server" }, status: :forbidden
  end
end
