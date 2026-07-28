class ServerConnectionsController < ApplicationController
  before_action :set_server_connection, only: %i[show edit update destroy test_connection]

  def index
    @server_connections = current_user.server_connections.order(:name)
  end

  def show; end

  def new
    @server_connection = current_user.server_connections.new(provider: :jellyfin)
  end

  def edit; end

  def create
    @server_connection = current_user.server_connections.new(server_connection_params)

    if @server_connection.save
      redirect_to @server_connection, notice: "Server connection created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @server_connection.update(server_connection_params)
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
    @server_connection = current_user.server_connections.find(params.expect(:id))
  end

  def server_connection_params
    permitted = params.expect(server_connection: %i[name provider base_url username password])
    permitted.delete(:password) if permitted[:password].blank?
    permitted
  end
end
