class ServerConnectionsController < ApplicationController
  before_action :set_server_connection, only: %i[show edit update destroy test_connection]
  before_action :set_media_server, only: %i[index new create start_quick_connect]

  def index
    @server_connection = current_user.server_connections.includes(:media_server).first
  end

  def show; end

  def new
    redirect_to server_connections_path, notice: "Your Jellyfin account is already connected." and return if current_user.server_connections.exists?

    @server_connection = current_user.server_connections.new(media_server: @media_server || MediaServer.new(provider: :jellyfin))
  end

  def edit; end

  def create
    @server_connection = current_user.server_connections.new(connection_params.merge(media_server: @media_server))

    if create_connection
      redirect_to @server_connection, notice: "Server connection created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def start_quick_connect
    redirect_to server_connections_path, notice: "Your Jellyfin account is already connected." and return if current_user.server_connections.exists?

    @media_server ||= build_initial_media_server
    return render(:new, status: :unprocessable_entity) unless @media_server

    @media_server.save! if @media_server.new_record?
    quick_connect = jellyfin_client(@media_server).initiate_quick_connect
    session[:quick_connect] = { "media_server_id" => @media_server.id, "secret" => quick_connect.fetch("Secret"), "code" => quick_connect.fetch("Code") }
    redirect_to quick_connect_server_connections_path
  rescue Integrations::Jellyfin::Client::ConnectionError => error
    @server_connection = current_user.server_connections.new(media_server: @media_server || MediaServer.new(provider: :jellyfin))
    @server_connection.errors.add(:base, error.message)
    render :new, status: :unprocessable_entity
  end

  def quick_connect
    @quick_connect = session[:quick_connect]
    redirect_to server_connections_path, alert: "Start a new Jellyfin connection to receive a code." unless @quick_connect
  end

  def quick_connect_status
    quick_connect = session[:quick_connect]
    return render json: { status: "expired" }, status: :unprocessable_entity unless quick_connect

    media_server = MediaServer.find(quick_connect.fetch("media_server_id"))
    client = jellyfin_client(media_server)
    state = client.quick_connect_state(quick_connect.fetch("secret"))
    return render json: { status: "pending" } unless state.fetch("Authenticated")

    authentication = client.authenticate_with_quick_connect(quick_connect.fetch("secret"))
    connection = current_user.server_connections.find_or_initialize_by(media_server: media_server)
    connection.assign_attributes(username: authentication.dig("User", "Name"), access_token: authentication.fetch("AccessToken"), password: nil)
    connection.save!
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
    @server_connection.destroy!
    redirect_to server_connections_url, notice: "Server connection removed."
  end

  def test_connection
    result = ServerConnections::TestConnection.new(@server_connection).call
    flash[result.success? ? :notice : :alert] = result.message

    redirect_to @server_connection
  end

  private

  def set_server_connection
    @server_connection = current_user.server_connections.includes(:media_server).find(params.expect(:id))
  end

  def set_media_server
    @media_server = MediaServer.configured
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
end
