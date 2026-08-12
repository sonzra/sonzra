require "test_helper"

class OfflineDownloadsControllerTest < ActionDispatch::IntegrationTest
  test "shows the device-local downloads library" do
    get offline_downloads_path

    assert_response :success
    assert_select "h1", "Downloads"
    assert_select "[data-controller='offline-library']"
  end
end
