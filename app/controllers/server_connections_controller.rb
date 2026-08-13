class ServerConnectionsController < ApplicationController
  before_action :set_server_connection, only: %i[show edit update destroy test_connection]
  before_action :set_media_server, only: %i[create start_quick_connect]

  def index
    @server_connections = current_user.server_connections.includes(:media_server).order(:created_at)
    @available_media_servers = MediaServer.where.not(id: @server_connections.select(:media_server_id)).order(:name)
  end

  def show; end

  def new
    @media_server = if params[:media_server_id].present?
      MediaServer.find(params[:media_server_id])
    elsif params[:setup].present? && current_user.admin?
      MediaServer.new
    end
    @available_media_servers = MediaServer.where.not(id: current_user.server_connections.select(:media_server_id)).order(:name)
    @server_connection = current_user.server_connections.new(media_server: @media_server) if @media_server
  end

  def edit; end

  def create
    @server_connection = current_user.server_connections.new(connection_params.merge(media_server: @media_server))

    if create_connection
      current_user.update!(preferred_server_connection: @server_connection) unless current_user.preferred_server_connection
      redirect_to @server_connection, notice: "Server connection created."
    else
      render_new_connection(status: :unprocessable_entity)
    end
  end

  def start_quick_connect
    @media_server ||= build_initial_media_server
    return render_new_connection(status: :unprocessable_entity) unless @media_server

    @media_server.save! if @media_server.new_record?
    session[:quick_connect] = quick_connect_session(@media_server)
    redirect_to quick_connect_server_connections_path
  rescue Integrations::Jellyfin::Client::ConnectionError => error
    @server_connection = current_user.server_connections.new(media_server: @media_server || MediaServer.new)
    @server_connection.errors.add(:base, error.message)
    render_new_connection(status: :unprocessable_entity)
  end

  def quick_connect
    @quick_connect = session[:quick_connect]
    redirect_to server_connections_path, alert: "Start a new server connection to receive an approval code." unless @quick_connect
  end

  def quick_connect_status
    quick_connect = session[:quick_connect]
    return render json: { status: "expired" }, status: :unprocessable_entity unless quick_connect

    media_server = MediaServer.find(quick_connect.fetch("media_server_id"))
    if media_server.plex?
      plex_quick_connect_status(media_server, quick_connect)
      return
    end

    client = jellyfin_client(media_server)
    state = client.quick_connect_state(quick_connect.fetch("secret"))
    return render json: { status: "pending" } unless state.fetch("Authenticated")

    authentication = client.authenticate_with_quick_connect(quick_connect.fetch("secret"))
    connection = current_user.server_connections.find_or_initialize_by(media_server: media_server)
    connection.assign_attributes(username: authentication.dig("User", "Name"), access_token: authentication.fetch("AccessToken"), password: nil)
    connection.save!
    current_user.update!(preferred_server_connection: connection) unless current_user.preferred_server_connection
    session[:server_remote_user_ids] = session.fetch(:server_remote_user_ids, {}).merge(connection.id.to_s => authentication.dig("User", "Id"))
    session.delete(:quick_connect)
    render json: { status: "connected", redirect_url: server_connections_path }
  rescue Integrations::Jellyfin::Client::AuthenticationError, Integrations::Jellyfin::Client::ConnectionError, ActiveRecord::RecordInvalid => error
    render json: { status: "error", message: error.message }, status: :unprocessable_entity
  end

  def update
    if update_connection
      redirect_to @server_connection, notice: "Server connection updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    was_active = session[:active_server_connection_id].to_i == @server_connection.id
    was_preferred = current_user.preferred_server_connection_id == @server_connection.id
    current_user.update!(preferred_server_connection: nil) if was_preferred
    @server_connection.destroy!
    current_user.update!(preferred_server_connection: current_user.server_connections.order(:created_at).first) if was_preferred
    session.delete(:active_server_connection_id) if was_active
    redirect_to server_connections_url, notice: "Server connection removed."
  end

  def test_connection
    result = ServerConnections::TestConnection.new(@server_connection).call
    respond_to do |format|
      format.html do
        flash[result.success? ? :notice : :alert] = result.message
        redirect_back fallback_location: server_connections_path
      end
      format.json { render json: { success: result.success?, message: result.message }, status: result.success? ? :ok : :unprocessable_entity }
    end
  end

  private

  def set_server_connection
    @server_connection = current_user.server_connections.includes(:media_server).find(params.expect(:id))
  end

  def set_media_server
    media_server_id = params.dig(:server_connection, :media_server_id)
    @media_server = MediaServer.find_by(id: media_server_id) if media_server_id.present?
    @media_server ||= MediaServer.configured unless params.dig(:server_connection, :setup_server) == "true"
  end

  def render_new_connection(status:)
    @available_media_servers = MediaServer.where.not(id: current_user.server_connections.select(:media_server_id)).order(:name)
    render :new, status:
  end

  def connection_params
    permitted = params.fetch(:server_connection, {}).permit(:username, :password)
    permitted.delete(:password) if permitted[:password].blank?
    permitted
  end

  def media_server_params
    params.expect(server_connection: %i[name provider base_url]).to_h
  end

  def create_connection
    return @server_connection.save if @media_server
    unless current_user.admin?
      @server_connection.media_server = MediaServer.new(media_server_params)
      @server_connection.errors.add(:base, "Only an administrator can configure the server.")
      return false
    end

    @media_server = MediaServer.new(media_server_params)
    @server_connection.media_server = @media_server
    return copy_media_server_errors unless @media_server.valid?
    return false unless @server_connection.valid?

    ApplicationRecord.transaction do
      @media_server.save!
      @server_connection.save!
    end
    true
  end

  def update_connection
    @media_server = @server_connection.media_server
    @server_connection.assign_attributes(connection_params)

    if current_user.admin?
      @media_server.assign_attributes(media_server_params)
      return copy_media_server_errors unless @media_server.valid?
    end

    return false unless @server_connection.valid?

    ApplicationRecord.transaction do
      @media_server.save! if current_user.admin?
      @server_connection.save!
    end
    true
  end

  def copy_media_server_errors
    @media_server.errors.full_messages.each { |message| @server_connection.errors.add(:base, message) }
    false
  end

  def build_initial_media_server
    unless current_user.admin?
      @server_connection = current_user.server_connections.new(media_server: MediaServer.new(media_server_params))
      @server_connection.errors.add(:base, "Only an administrator can configure the server.")
      return nil
    end

    MediaServer.new(media_server_params).tap do |media_server|
      unless media_server.valid?
        @server_connection = current_user.server_connections.new(media_server: media_server)
        @media_server = media_server
        copy_media_server_errors
        return nil
      end
    end
  end

  def jellyfin_client(media_server)
    Integrations::Jellyfin::Client.new(base_url: media_server.base_url)
  end

  def plex_client(media_server, access_token: nil)
    Integrations::Plex::Client.new(base_url: media_server.base_url, access_token:)
  end

  def quick_connect_session(media_server)
    if media_server.plex?
      plex_client(media_server).initiate_pin(forward_url: quick_connect_server_connections_url).merge("media_server_id" => media_server.id, "provider" => "plex")
    else
      quick_connect = jellyfin_client(media_server).initiate_quick_connect
      { "media_server_id" => media_server.id, "secret" => quick_connect.fetch("Secret"), "code" => quick_connect.fetch("Code"), "provider" => "jellyfin" }
    end
  end

  def plex_quick_connect_status(media_server, quick_connect)
    client = plex_client(media_server)
    access_token = client.pin_status(pin_id: quick_connect.fetch("id"), code: quick_connect.fetch("code"))
    return render json: { status: "pending" } if access_token.blank?

    connection = current_user.server_connections.find_or_initialize_by(media_server: media_server)
    connection.assign_attributes(username: client.authenticated_account_name(access_token:), access_token:, password: nil)
    connection.save!
    current_user.update!(preferred_server_connection: connection) unless current_user.preferred_server_connection
    session.delete(:quick_connect)
    render json: { status: "connected", redirect_url: server_connections_path }
  end
end
