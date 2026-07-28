require "test_helper"

class Admin::RegistrationSettingsControllerTest < ActionDispatch::IntegrationTest
  test "allows an administrator to disable registrations" do
    users(:one).update!(admin: true)

    get admin_registration_settings_path
    assert_response :success

    patch admin_registration_settings_path, params: { application_setting: { registrations_enabled: "0" } }

    assert_redirected_to admin_registration_settings_path
    assert_not ApplicationSetting.instance.registrations_enabled?

    follow_redirect!
    assert_select ".flash", "Settings saved."
    assert_select ".settings-status", /disabled/
  end

  test "does not allow non-administrators to access registration settings" do
    users(:one).update!(admin: false)

    get admin_registration_settings_path

    assert_redirected_to root_path
  end
end
