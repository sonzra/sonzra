class AdminController < ApplicationController
  before_action :require_administrator

  private

  def require_administrator
    return if current_user.admin?

    redirect_to root_path, alert: "You do not have access to administration."
  end
end
