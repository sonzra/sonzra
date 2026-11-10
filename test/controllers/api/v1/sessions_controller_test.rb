require "test_helper"

module Api
  module V1
    class SessionsControllerTest < ActionDispatch::IntegrationTest
      setup do
        @user = users(:one)
      end

      test "creates a session with valid credentials" do
        sign_out
        post api_v1_session_url, params: {
          email_address: @user.email_address,
          password: "password"
        }

        assert_response :created
        json = JSON.parse(response.body)
        assert json["token"].present?
        assert json["session_id"].present?
        assert_equal @user.id, json["user"]["id"]
        assert_equal @user.email_address, json["user"]["email_address"]
      end

      test "rejects session creation with invalid credentials" do
        sign_out
        post api_v1_session_url, params: {
          email_address: @user.email_address,
          password: "wrong_password"
        }

        assert_response :unauthorized
        json = JSON.parse(response.body)
        assert_equal "Invalid email address or password", json["error"]
      end

      test "shows current session info when authenticated" do
        get api_v1_session_url
        assert_response :success
        json = JSON.parse(response.body)
        assert_equal @user.id, json["user"]["id"]
        assert json["session_id"].present?
      end

      test "destroys active session" do
        delete api_v1_session_url
        assert_response :success
        json = JSON.parse(response.body)
        assert_equal "logged_out", json["status"]
      end
    end
  end
end
