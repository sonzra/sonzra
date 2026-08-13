class ApplicationController < ActionController::Base
  include Authentication
  allow_browser versions: :modern

  helper_method :registrations_enabled?, :current_server_connection

  private

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
end
