require "test_helper"

class RegistrationsControllerTest < ActionDispatch::IntegrationTest
  test "renders registration page" do
    get new_registration_path
    assert_response :success
  end

  test "creates user and logs them in" do
    assert_difference("User.count", 1) do
      post registration_path, params: {
        user: { email_address: "new-user@example.com", password: "password", password_confirmation: "password" }
      }
    end

    assert_redirected_to new_server_connection_path
    assert_not_nil cookies[:session_id]
  end

  test "blocks registrations when disabled" do
    ApplicationSetting.instance.update!(registrations_enabled: false)

    get new_registration_path
    assert_redirected_to new_session_path

    assert_no_difference("User.count") do
      post registration_path, params: {
        user: { email_address: "new-user@example.com", password: "password", password_confirmation: "password" }
      }
    end

    assert_redirected_to new_session_path
  end

  test "blocks registrations when SONZRA_OPEN_REGISTRATION is false even if db setting is true" do
    ApplicationSetting.instance.update!(registrations_enabled: true)

    with_env("SONZRA_OPEN_REGISTRATION" => "false") do
      get new_registration_path
      assert_redirected_to new_session_path

      assert_no_difference("User.count") do
        post registration_path, params: {
          user: { email_address: "blocked@example.com", password: "password", password_confirmation: "password" }
        }
      end
      assert_redirected_to new_session_path
    end
  end

  test "allows registrations when SONZRA_OPEN_REGISTRATION is true even if db setting is false" do
    ApplicationSetting.instance.update!(registrations_enabled: false)

    with_env("SONZRA_OPEN_REGISTRATION" => "true") do
      get new_registration_path
      assert_response :success

      assert_difference("User.count") do
        post registration_path, params: {
          user: { email_address: "allowed@example.com", password: "password", password_confirmation: "password" }
        }
      end
      assert_redirected_to new_server_connection_path
    end
  end

  test "renders registration page with neutralized media server copy" do
    get new_registration_path
    assert_response :success
    assert_select ".auth-sign-in-copy", /keep your media server connection/
  end

  private

  def with_env(hash)
    old = {}
    hash.each do |k, v|
      old[k] = ENV[k]
      if v.nil?
        ENV.delete(k)
      else
        ENV[k] = v
      end
    end
    yield
  ensure
    old.each do |k, v|
      if v.nil?
        ENV.delete(k)
      else
        ENV[k] = v
      end
    end
  end
end
