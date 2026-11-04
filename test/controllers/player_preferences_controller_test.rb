require "test_helper"

class PlayerPreferencesControllerTest < ActionDispatch::IntegrationTest
  test "stores the radio player preference in the session" do
    patch player_preferences_url, params: { radio_enabled: true }, as: :json

    assert_response :no_content
    assert_equal true, session[:player_preferences]["radio_enabled"]
  end

  test "stores the preload_on_wifi_only player preference in the session" do
    patch player_preferences_url, params: { preload_on_wifi_only: true }, as: :json

    assert_response :no_content
    assert_equal true, session[:player_preferences]["preload_on_wifi_only"]
  end

  test "preserves existing preferences when updating another" do
    patch player_preferences_url, params: { radio_enabled: true }, as: :json
    patch player_preferences_url, params: { preload_on_wifi_only: true }, as: :json

    assert_response :no_content
    assert_equal true, session[:player_preferences]["radio_enabled"]
    assert_equal true, session[:player_preferences]["preload_on_wifi_only"]
  end
end
