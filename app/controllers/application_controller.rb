class ApplicationController < ActionController::Base
  include Authentication
  allow_browser versions: :modern

  helper_method :registrations_enabled?, :current_server_connection, :redesign_enabled?, :current_device_id

  private

  def current_device_id
    session[:sonzra_device_id] ||= "sonzra-web-#{SecureRandom.hex(6)}"
  end

  def server_access_token(server_connection)
    return unless server_connection

    session.dig(:server_access_tokens, server_connection.id.to_s)
  end

  def store_server_access_token(server_connection, token)
    return unless server_connection && token.present?

    session[:server_access_tokens] = session.fetch(:server_access_tokens, {}).merge(server_connection.id.to_s => token)
  end

  def registrations_enabled?
    ApplicationSetting.instance.registrations_enabled?
  end

  def current_server_connection
    connections = current_user.server_connections.order(:created_at)
    selected_id = session[:active_server_connection_id]
    selected = connections.find_by(id: selected_id) if selected_id
    selected ||= connections.find_by(id: current_user.preferred_server_connection_id)
    selected ||= connections.first
    session[:active_server_connection_id] = selected.id if selected
    selected
  end

  def redesign_enabled?
    authenticated? && current_user.ui_variant == "redesign"
  end
end
