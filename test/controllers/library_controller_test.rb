require "test_helper"

class LibraryControllerTest < ActionDispatch::IntegrationTest
  test "renders the audiobook library page" do
    get library_audiobooks_url

    assert_response :success
    assert_select "h1", "Connect a server to browse your library."
    assert_select "a[href='#{server_connections_path}']", "Connect Jellyfin"
  end

  test "renders the podcast library page" do
    get library_podcasts_url

    assert_response :success
    assert_select "h1", "Connect a server to browse your library."
  end

  test "renders the playlist library page" do
    get library_playlists_url

    assert_response :success
    assert_select "h1", "Connect a server to browse your library."
  end

  test "renders the genre directory" do
    get library_genres_url

    assert_response :success
    assert_select "h1", "Connect a server to browse your library."
  end
end
