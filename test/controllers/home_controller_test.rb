require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "renders the Sonzra home page" do
    get root_url

    assert_response :success
    assert_select "link[rel='stylesheet'][href*='media_content']", minimum: 1
    assert_select "link[rel='stylesheet'][href*='responsive']", minimum: 1
    assert_select "h1", "Getting your music ready…"
    assert_select "aside#player[data-turbo-permanent][aria-label='Now playing']"
    assert_select "[data-player-target='elapsed']", "0:00"
    assert_select "[data-player-target='duration']", "0:00"
    assert_select "button[aria-label='Show queue']"
    assert_select "[data-player-target='queuePanel'][hidden]"
    assert_select "button[aria-label='Previous track']"
    assert_select "button[aria-label='Next track']"
    assert_select "aside#player button[aria-label='Previous track']"
    assert_select "aside#player button[aria-label='Next track']"
    assert_select "aside#player [data-player-target='volume']"
    assert_select "[data-player-target='expandedTimeline']"
    assert_select "a[href='#{server_connections_path}']", minimum: 1
    assert_select "a[href='#{library_audiobooks_path}']", "Audiobooks"
    assert_select "a[href='#{library_podcasts_path}']", "Podcasts"
  end

  test "renders connection guidance when no server exists" do
    get home_content_url

    assert_response :success
    assert_select "h1", "Connect a server to begin."
  end
end
