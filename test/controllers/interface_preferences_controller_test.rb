require "test_helper"

class InterfacePreferencesControllerTest < ActionDispatch::IntegrationTest
  test "persists the current user's redesign preference" do
    patch interface_preference_url, params: { ui_variant: "redesign" }

    assert_redirected_to root_url
    assert_equal "redesign", users(:one).reload.ui_variant
  end

  test "rejects an unknown interface variant" do
    patch interface_preference_url, params: { ui_variant: "neon" }

    assert_response :unprocessable_entity
    assert_equal "legacy", users(:one).reload.ui_variant
  end
end
