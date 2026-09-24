require "test_helper"

class OfflineDownloadsControllerTest < ActionDispatch::IntegrationTest
  test "shows the device-local downloads library" do
    get offline_downloads_path

    assert_response :success
    assert_select "h1", "Downloads"
    assert_select "[data-controller='offline-library']"
  end

  test "uses the standalone redesign downloads collection layout" do
    users(:one).update!(ui_variant: "redesign")

    get offline_downloads_path

    assert_response :success
    assert_select ".redesign-downloads-page[data-controller='offline-library']"
    assert_select ".redesign-library-heading h1", "Downloads"
    assert_select ".redesign-downloads-content-heading h2", "Downloaded albums"
    assert_select ".redesign-downloads-page .offline-downloads__list"
    assert_select ".redesign-downloads-track-section__heading span:first-child", "Track"
  end
end
