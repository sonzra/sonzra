require "test_helper"

class PlayerPreferencesControllerTest < ActionDispatch::IntegrationTest
  test "stores the radio player preference in the session" do
    patch player_preferences_url, params: { radio_enabled: true }, as: :json

    assert_response :no_content
    assert_equal true, session[:player_preferences]["radio_enabled"]
  end
end
