require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  test "renders the Sonzra home page" do
    get root_url

    assert_response :success
    assert_select "link[rel='stylesheet'][href*='media_content']", minimum: 1
    assert_select "link[rel='stylesheet'][href*='responsive']", minimum: 1
    assert_select "link[rel='stylesheet'][href*='interaction']", minimum: 1
    assert_select "link[rel='stylesheet'][href*='navigation']", minimum: 1
    assert_select "link[rel='stylesheet'][href*='mobile_player']", minimum: 1
    assert_select "link[rel='stylesheet'][href*='touch_cards']", minimum: 1
    assert_select "link[rel='stylesheet'][href*='album_details']", minimum: 1
    assert_select "link[rel='stylesheet'][href*='card_options']", minimum: 1
    assert_select "h1", "Getting your music ready…"
    assert_select "html[data-controller='player']"
    assert_select "body[data-controller='player']", count: 0
    assert_select "body[data-controller~='card-options'][data-controller~='media-header']"
    assert_select "aside#player[data-player-target='shell'][data-turbo-permanent][aria-label='Now playing'][hidden]"
    assert_select "aside#player audio[preload='auto'][playsinline]"
    assert_select "#player-feedback[data-player-target='queueFeedback'][data-turbo-permanent][role='status'][hidden]"
    assert_select "#card-options-sheet[data-card-options-target='sheet'][hidden]"
    assert_select "aside#player [data-player-target='miniProgress']"
    assert_select "[data-player-target='queuePanel'][hidden]"
    assert_select "#player-queue[data-turbo-permanent][data-player-target='queuePanel']"
    assert_select "button[aria-label='Previous track']"
    assert_select "button[aria-label='Next track']"
    assert_select "aside#player button.listen-player__track[data-action='player#openQueue']"
    assert_select "aside#player button[aria-label='Show queue']", count: 0
    assert_select "aside#player button.listen-player__play[data-action='player#toggle']"
    assert_select "aside#player button.listen-player__skip[aria-label='Previous track'][data-action='player#previous']", 1
    assert_select "aside#player button.listen-player__skip[aria-label='Next track'][data-action='player#next']", 1
    assert_select "aside#player .listen-player__controls > .listen-player__time:first-child", 1
    assert_select "aside#player .listen-player__controls > button:nth-child(2).listen-player__favorite[data-action='player#toggleFavorite']", 1
    assert_select "aside#player .listen-player__time [data-player-target='elapsed']", "0:00"
    assert_select "aside#player .listen-player__time [data-player-target='duration']", "0:00"
    assert_select "aside#player [data-player-target='volume']", count: 0
    assert_select "[data-player-target='expandedTimeline']"
    assert_select "a[href='#{server_connections_path}']", minimum: 1
    assert_select "a[href='#{library_audiobooks_path}']", "Audiobooks"
    assert_select "a[href='#{library_podcasts_path}']", "Podcasts"
    assert_select "header[data-controller='navigation'] button[aria-label='Open navigation menu'][aria-expanded='false']"
    assert_select "header[data-controller='navigation'] a[href='#{server_connections_path}']", minimum: 1
  end

  test "renders connection guidance when no server exists" do
    get home_content_url

    assert_response :success
    assert_select "h1", "Connect a server to begin."
    assert_select "a[href='#{server_connections_path}'][data-turbo-frame='_top']", "Connect Jellyfin"
  end
end
