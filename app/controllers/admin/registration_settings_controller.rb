class Admin::RegistrationSettingsController < AdminController
  def show
    @application_setting = ApplicationSetting.instance
  end

  def update
    @application_setting = ApplicationSetting.instance

    if @application_setting.update(registration_settings_params)
      redirect_to admin_registration_settings_path, notice: "Settings saved."
    else
      render :show, status: :unprocessable_entity
    end
  end

  private

  def registration_settings_params
    params.expect(application_setting: [ :registrations_enabled ])
  end
end
