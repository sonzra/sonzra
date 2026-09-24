require "test_helper"

class LibraryControllerTest < ActionDispatch::IntegrationTest
  test "renders the audiobook library page" do
    get library_audiobooks_url

    assert_response :success
    assert_select "h1", "Connect a server to browse your library."
    assert_select "a[href='#{server_connections_path}']", "Connect Jellyfin"
  end

  test "uses the redesigned collection setup state when no server exists" do
    users(:one).update!(ui_variant: "redesign")

    get library_audiobooks_url

    assert_response :success
    assert_select "main.redesign-utility-page .redesign-state"
    assert_select ".redesign-state .eyebrow", "Your collection"
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

  test "renders artists page with infinite scroll layout and alphabet sidebar for jellyfin connection" do
    users(:one).update!(ui_variant: "redesign")
    ServerConnection.create!(
      media_server: MediaServer.create!(name: "Home", provider: :jellyfin, base_url: "https://example.com"),
      username: "bruno",
      password: "secret",
      user: users(:one)
    )
    response = Integrations::Jellyfin::LibraryCollectionResponseData.new(
      content: [ { "Id" => "artist-1", "Name" => "Beatles", "Type" => "MusicArtist" } ],
      total: 100,
      access_token: "token"
    )
    client = Object.new
    client.define_singleton_method(:library_collection) { |_, **| response }
    client.define_singleton_method(:supports?) { |cap| cap == :letter_filtering }

    client_class = Integrations::Jellyfin::Client
    client_class.singleton_class.alias_method :new_before_artists_test, :new
    client_class.define_singleton_method(:new) { |**| client }
    begin
      get library_artists_url(letter: "B")
    ensure
      client_class.singleton_class.alias_method :new, :new_before_artists_test
      client_class.singleton_class.remove_method :new_before_artists_test
    end

    assert_response :success
    assert_select ".redesign-library-page"
    assert_select ".redesign-library-heading h1", "Library"
    assert_select ".redesign-library-content__heading h2", "Artists"
    assert_select ".redesign-library-layout"
    assert_select ".redesign-library-tabs a", 6
    assert_select ".redesign-library-tabs a[aria-current='page'] b", "100"
    assert_select ".library-page-layout--browsable[data-controller='library-pagination']"
    assert_select ".library-alphabet button.is-active", "B"
    assert_select ".listen-card h3 a", "Beatles"
  end

  test "renders genre cards in the standalone redesign grid" do
    users(:one).update!(ui_variant: "redesign")
    ServerConnection.create!(
      media_server: MediaServer.create!(name: "Home", provider: :jellyfin, base_url: "https://example.com"),
      username: "bruno",
      password: "secret",
      user: users(:one)
    )
    response = Integrations::Jellyfin::LibraryCollectionResponseData.new(
      content: [ { "Id" => "ambient", "Name" => "Ambient", "Type" => "MusicGenre" }, { "Id" => "jazz", "Name" => "Jazz", "Type" => "MusicGenre" } ],
      total: 2,
      access_token: "token"
    )
    client = Object.new
    client.define_singleton_method(:library_collection) { |_, **| response }

    client_class = Integrations::Jellyfin::Client
    client_class.singleton_class.alias_method :new_before_redesign_genres_test, :new
    client_class.define_singleton_method(:new) { |**| client }
    begin
      get library_genres_url
    ensure
      client_class.singleton_class.alias_method :new, :new_before_redesign_genres_test
      client_class.singleton_class.remove_method :new_before_redesign_genres_test
    end

    assert_response :success
    assert_select ".redesign-library-page"
    assert_select ".redesign-library-heading h1", "Library"
    assert_select ".redesign-library-content__heading h2", "All genres"
    assert_select ".redesign-genre-directory .redesign-genre-tile", 2
    assert_select ".redesign-genre-tile--0", "Ambient"
    assert_select ".redesign-genre-tile--1", "Jazz"
  end

  test "searches artists, albums, and tracks from the global search route" do
    users(:one).update!(ui_variant: "redesign")
    connection = ServerConnection.create!(
      media_server: MediaServer.create!(name: "Home", provider: :jellyfin, base_url: "https://example.com"),
      username: "bruno",
      password: "secret",
      user: users(:one)
    )
    calls = []
    results = {
      artists: [ { "Id" => "artist-1", "Name" => "The Beatles", "Type" => "MusicArtist" } ],
      albums: [ { "Id" => "album-1", "Name" => "Abbey Road", "Type" => "MusicAlbum", "AlbumArtist" => "The Beatles" } ],
      songs: [ { "Id" => "track-1", "Name" => "Come Together", "Type" => "Audio", "AlbumArtist" => "The Beatles", "RunTimeTicks" => 30_000_000 } ]
    }
    client = Object.new
    client.define_singleton_method(:library_collection) do |collection, page:, query:, **|
      calls << [ collection, query ]
      items = query == "Beatles" ? results.fetch(collection, []) : []
      Integrations::Jellyfin::LibraryCollectionResponseData.new(content: items, total: items.size, access_token: "token")
    end

    client_class = Integrations::Jellyfin::Client
    client_class.singleton_class.alias_method :new_before_global_search_test, :new
    client_class.define_singleton_method(:new) { |**| client }
    begin
      get library_search_url(q: "Beatles")
    ensure
      client_class.singleton_class.alias_method :new, :new_before_global_search_test
      client_class.singleton_class.remove_method :new_before_global_search_test
    end

    assert_response :success
    assert_select ".redesign-search-page h1", "“Beatles”"
    assert_select "#search-artists-title", "Artists"
    assert_select ".redesign-search-section .listen-card h3 a", "The Beatles"
    assert_select "#search-albums-title", "Albums"
    assert_select ".redesign-search-track-list .library-media-list__details a", "Come Together"
    assert_select ".redesign-search-track-list .library-media-list__play[aria-label='Play Come Together']"
    assert_select ".redesign-search-track-list .listen-card__play[aria-label='Play Come Together']"
    assert_select ".redesign-search-track-list .library-media-list__queue[aria-label='Add Come Together to queue']"
    assert_select ".redesign-search-track-list .listen-card__options-toggle[aria-label='More options for Come Together']"
    assert_equal %i[artists albums songs], calls.select { |_, query| query == "Beatles" }.map(&:first)
    assert_equal connection.id.to_s, session[:server_access_tokens].keys.first
  end

  test "renders all favorite tracks with redesign actions" do
    users(:one).update!(ui_variant: "redesign")
    connection = ServerConnection.create!(
      media_server: MediaServer.create!(name: "Home", provider: :jellyfin, base_url: "https://example.com"),
      username: "bruno",
      password: "secret",
      user: users(:one)
    )
    response = Integrations::Jellyfin::LibraryCollectionResponseData.new(
      content: [ { "Id" => "track-1", "Name" => "Come Together", "Type" => "Audio", "AlbumArtist" => "The Beatles", "RunTimeTicks" => 30_000_000, "UserData" => { "IsFavorite" => true } } ],
      total: 1,
      access_token: "token"
    )
    calls = []
    client = Object.new
    client.define_singleton_method(:library_collection) do |collection, **|
      calls << collection
      response
    end

    client_class = Integrations::Jellyfin::Client
    client_class.singleton_class.alias_method :new_before_favorites_template_test, :new
    client_class.define_singleton_method(:new) { |**| client }
    begin
      get favorites_url
    ensure
      client_class.singleton_class.alias_method :new, :new_before_favorites_template_test
      client_class.singleton_class.remove_method :new_before_favorites_template_test
    end

    assert_response :success
    assert_select ".redesign-favorites-page h1", "Favorites"
    assert_select ".redesign-favorite-track-list .library-media-list__details a", "Come Together"
    assert_select ".redesign-favorite-track-list .favorites-track__favorite[data-detail-favorite-favorited-value='true']"
    assert_select ".redesign-favorite-track-list .library-media-list__play[aria-label='Play Come Together']"
    assert_select ".redesign-favorite-track-list .library-media-list__queue", 0
    assert_select ".redesign-favorite-track-list .listen-card__options-toggle[aria-label='More options for Come Together']"
    assert_select "#card-options-sheet [data-card-options-target='queueAction']", "Add to queue"
    assert_select ".redesign-topbar__link[href='#{favorites_path}']", "Favorites"
    assert_select ".redesign-mobile-menu a[href='#{favorites_path}']", "Favorites"
    assert_select "body[data-controller~='tooltip']", 0
    assert_equal [ :favorite_tracks ], calls
    assert_equal connection.id.to_s, session[:server_access_tokens].keys.first
  end

  test "keeps the favorites route exclusive to the redesign" do
    get favorites_url

    assert_redirected_to root_url
  end

  test "renders turbo stream append response for infinite scroll request" do
    ServerConnection.create!(
      media_server: MediaServer.create!(name: "Home", provider: :jellyfin, base_url: "https://example.com"),
      username: "bruno",
      password: "secret",
      user: users(:one)
    )
    mock_data_response = Integrations::Jellyfin::LibraryCollectionResponseData.new(
      content: [ { "Id" => "artist-2", "Name" => "Coldplay", "Type" => "MusicArtist" } ],
      total: 100,
      access_token: "token"
    )
    client = Object.new
    client.define_singleton_method(:library_collection) { |_, **| mock_data_response }
    client.define_singleton_method(:supports?) { |cap| cap == :letter_filtering }

    client_class = Integrations::Jellyfin::Client
    client_class.singleton_class.alias_method :new_before_stream_test, :new
    client_class.define_singleton_method(:new) { |**| client }
    begin
      get library_artists_url(page: 2, format: :turbo_stream)
    ensure
      client_class.singleton_class.alias_method :new, :new_before_stream_test
      client_class.singleton_class.remove_method :new_before_stream_test
    end

    assert_response :success
    assert_match 'turbo-stream action="append" target="library-grid"', @response.body
    assert_match 'turbo-stream action="replace" target="library-scroll-state"', @response.body
    assert_match "Coldplay", @response.body
  end
end
