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

  test "renders music shelf pages" do
    [ library_recently_played_url, library_most_played_songs_url, library_recently_added_albums_url ].each do |url|
      get url

      assert_response :success
      assert_select "h1", "Connect a server to browse your library."
    end
  end

  test "renders the recently played collection template when a server is connected" do
    ServerConnection.create!(
      media_server: MediaServer.create!(name: "Home", provider: :jellyfin, base_url: "https://example.com"),
      username: "bruno",
      password: "secret",
      user: users(:one)
    )
    response = Integrations::Jellyfin::LibraryCollectionResponseData.new(
      content: [ { "Id" => "track-1", "Name" => "A track", "Type" => "Audio" } ],
      total: 1,
      access_token: "token"
    )
    client = Object.new
    client.define_singleton_method(:library_collection) { |_, **| response }

    client_class = Integrations::Jellyfin::Client
    client_class.singleton_class.alias_method :new_before_recently_played_template_test, :new
    client_class.define_singleton_method(:new) { |**| client }
    begin
      get library_recently_played_url
    ensure
      client_class.singleton_class.alias_method :new, :new_before_recently_played_template_test
      client_class.singleton_class.remove_method :new_before_recently_played_template_test
    end

    assert_response :success
    assert_select "h1", "Recently played"
    assert_select ".library-media-list__details a", "A track"
    assert_select ".library-media-list button[aria-label='Play A track']"
    assert_select ".library-media-list button[aria-label='Add A track to queue']"
  end
end
