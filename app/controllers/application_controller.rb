class ApplicationController < ActionController::Base
  include Authentication
  allow_browser versions: :modern

  helper_method :registrations_enabled?

  private

  def registrations_enabled?
    ApplicationSetting.instance.registrations_enabled?
  end
end
