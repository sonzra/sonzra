require "test_helper"

class OfflineShellsControllerTest < ActionDispatch::IntegrationTest
  test "renders the downloads library with the standard player in offline mode" do
    get offline_shell_path

    assert_response :success
    assert_select "body.offline-shell"
    assert_select "[data-player-offline-value='true']"
    assert_select "#player[data-player-target='shell']"
    assert_select "[data-controller='offline-library']"
    assert_select ".offline-connection [data-offline-connection-target='status']", "Checking connection…"
    assert_select "a.listen-topbar__link[aria-disabled='true']", minimum: 1
  end
end
