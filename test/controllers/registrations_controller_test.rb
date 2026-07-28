require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  test "creates an account and starts a session" do
    assert_difference("User.count") do
      post registration_path, params: {
        user: { email_address: "new-user@example.com", password: "password", password_confirmation: "password" }
      }
    end

    assert_redirected_to new_server_connection_path
    assert cookies[:session_id]
  end

  test "renders validation errors for invalid registrations" do
    post registration_path, params: { user: { email_address: "", password: "password", password_confirmation: "different" } }

    assert_response :unprocessable_entity
    assert_select "h2", /error/
  end

  test "does not allow new accounts when registrations are disabled" do
    ApplicationSetting.instance.update!(registrations_enabled: false)

    assert_no_difference("User.count") do
      post registration_path, params: {
        user: { email_address: "new-user@example.com", password: "password", password_confirmation: "password" }
      }
    end

    assert_redirected_to new_session_path
  end
end
