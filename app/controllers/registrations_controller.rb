class RegistrationsController < ApplicationController
  allow_unauthenticated_access only: %i[new create]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_registration_path, alert: "Try again later." }

  def new
    unless registrations_enabled?
      redirect_to new_session_path, alert: "New account registration is currently unavailable."
      return
    end

    @user = User.new
  end

  def create
    unless registrations_enabled?
      redirect_to new_session_path, alert: "New account registration is currently unavailable."
      return
    end

    @user = User.new(user_params)

    if @user.save
      start_new_session_for @user
      redirect_to new_server_connection_path, notice: "Your account is ready. Connect your Jellyfin user to begin."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def user_params
    params.expect(user: %i[email_address password password_confirmation])
  end
end
