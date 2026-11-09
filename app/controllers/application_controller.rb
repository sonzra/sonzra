class ApplicationController < ActionController::Base
  include Authentication
  allow_browser versions: :modern

  helper_method :registrations_enabled?, :current_server_connection, :current_device_id, :connection_alert_server_connection

  private

  def current_device_id
    instance_prefix = ENV["JELLYFIN_CLIENT_ID"].presence || ENV["SONZRA_INSTANCE_ID"].presence || "sonzra"
    session[:sonzra_device_id] ||= "#{instance_prefix}-web-#{SecureRandom.hex(6)}"
  end

  def server_access_token(server_connection)
    return unless server_connection

    token = server_connection.access_token.presence || session.dig(:server_access_tokens, server_connection.id.to_s)
    if token.present? && session.dig(:server_access_tokens, server_connection.id.to_s) != token
      session[:server_access_tokens] = session.fetch(:server_access_tokens, {}).merge(server_connection.id.to_s => token)
    end
    token
  end

  def connection_alert_server_connection
    return unless authenticated?
    return unless session[:connection_alert_server_connection_id].present?

    current_user.server_connections.find_by(id: session[:connection_alert_server_connection_id])
  end

  def record_connection_alert(server_connection)
    return unless server_connection

    session[:connection_alert_server_connection_id] = server_connection.id
  end

  def clear_connection_alert(server_connection)
    return unless server_connection

    session.delete(:connection_alert_server_connection_id) if session[:connection_alert_server_connection_id].to_s == server_connection.id.to_s
  end

  def store_server_access_token(server_connection, token)
    return unless server_connection && token.present?

    session[:server_access_tokens] = session.fetch(:server_access_tokens, {}).merge(server_connection.id.to_s => token)
    server_connection.update_column(:access_token, token) if server_connection.persisted? && server_connection.access_token != token
  end

  def registrations_enabled?
    return false if ENV["SONZRA_OPEN_REGISTRATION"] == "false"
    return true if ENV["SONZRA_OPEN_REGISTRATION"] == "true"

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
end
