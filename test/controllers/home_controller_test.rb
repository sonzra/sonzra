require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "renders the Sonzra home page" do
    get root_url

    assert_response :success
    assert_select "h1", "What do you want to hear?"
    assert_select "aside[aria-label='Now playing']"
    assert_select "a[href='#{server_connections_path}']", minimum: 1
  end
end
