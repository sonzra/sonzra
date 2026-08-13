class MediaServersController < ApplicationController
  before_action :require_admin

  def index
    @media_servers = MediaServer.includes(:server_connections).order(:name)
  end

  def destroy
    media_server = MediaServer.find(params.expect(:id))
    if media_server.server_connections.exists?
      redirect_to media_servers_path, alert: "Remove every user connection before removing #{media_server.name}."
    else
      media_server.destroy!
      redirect_to media_servers_path, notice: "#{media_server.name} was removed."
    end
  end

  private

  def require_admin
    return if current_user.admin?

    redirect_to server_connections_path, alert: "Only an administrator can manage server configurations."
  end
end
