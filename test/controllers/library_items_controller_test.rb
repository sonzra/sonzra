require "test_helper"

class LibraryItemsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @server_connection = ServerConnection.create!(
      name: "Library server",
      provider: :jellyfin,
      base_url: "https://jellyfin.example.com",
      username: "bruno",
      password: "secret",
      user: users(:one)
    )
  end

  test "renders an album play button that queues the complete album" do
    result = ServerConnections::FetchLibraryItemDetailsResultData.new(
      details: {
        item: { "Id" => "song-id", "Name" => "Song name", "Type" => "Audio", "AlbumArtist" => "Artist" },
        album: { "Id" => "album-id", "Name" => "Album name", "Type" => "MusicAlbum", "AlbumArtist" => "Artist", "AlbumArtists" => [ { "Id" => "artist-id" } ] },
        tracks: [],
        other_albums: [],
        similar_albums: []
      },
      access_token: "token",
      message: nil
    )
    service = Object.new
    service.define_singleton_method(:call) { result }

    service_class = ServerConnections::FetchLibraryItemDetails
    original_new = service_class.method(:new)
    service_class.define_singleton_method(:new) { |*_arguments| service }

    begin
      get library_item_server_connection_url(@server_connection, "song-id")
    ensure
      service_class.define_singleton_method(:new, original_new)
    end

    assert_response :success
    assert_select "header.media-topbar[data-media-header-target='bar'] a[href='#{library_albums_path}']", 1
    assert_select "header.media-topbar [data-media-header-target='thumbnail']"
    assert_select "header.listen-topbar", 0
    assert_select ".detail-hero__art[data-media-header-target='artwork']"
    assert_select ".detail-hero__art img[src='/brand/sonzra-mark.svg']", 1
    assert_select "button.detail-hero__album-play[data-action='player#replaceQueue'][data-player-queue-url-param='#{playback_queue_server_connection_path(@server_connection, "album-id")}'][aria-label='Play Album name']"
    assert_select ".detail-hero__artist a[href='#{library_item_server_connection_path(@server_connection, "artist-id")}']", "Artist"
  end

  test "renders dedicated audiobook controls with its saved playback position" do
    result = ServerConnections::FetchLibraryItemDetailsResultData.new(
      details: {
        item: { "Id" => "book-id", "Name" => "Book name", "Type" => "AudioBook", "RunTimeTicks" => 3_600_000_000, "UserData" => { "PlaybackPositionTicks" => 120_000_000 } },
        album: { "Id" => "book-id", "Name" => "Book name" },
        kind: :audiobook,
        tracks: [],
        other_albums: [],
        similar_albums: []
      },
      access_token: "token",
      message: nil
    )
    service = Object.new
    service.define_singleton_method(:call) { result }
    service_class = ServerConnections::FetchLibraryItemDetails
    original_new = service_class.method(:new)
    service_class.define_singleton_method(:new) { |*_arguments| service }

    get library_item_server_connection_url(@server_connection, "book-id")

    assert_response :success
    assert_select "header.media-topbar[data-media-header-target='bar'] a[href='#{library_audiobooks_path}']", 1
    assert_select "header.listen-topbar", 0
    assert_select ".detail-hero__art[data-media-header-target='artwork']"
    assert_select ".detail-hero__art img[src='/brand/sonzra-mark.svg']", 1
    assert_select ".detail-hero__kind", "Audiobook"
    assert_select "button[aria-label='Continue Book name from 0:12'][data-player-start-position-param='12.0']", 1
    assert_select "button[aria-label='Play Book name from the beginning'][data-player-start-position-param='0']", 1
  ensure
    service_class.define_singleton_method(:new, original_new)
  end

  test "uses the media navigation for artist details" do
    result = ServerConnections::FetchLibraryItemDetailsResultData.new(
      details: {
        item: { "Id" => "artist-id", "Name" => "Artist name", "Type" => "MusicArtist" },
        album: { "Id" => "artist-id", "Name" => "Artist name", "Type" => "MusicArtist" },
        tracks: [],
        other_albums: [ { "Id" => "album-id", "Name" => "Artist album", "Type" => "MusicAlbum", "PremiereDate" => "2024-01-01T00:00:00.0000000Z" } ],
        similar_albums: []
      },
      access_token: "token",
      message: nil
    )
    service = Object.new
    service.define_singleton_method(:call) { result }
    service_class = ServerConnections::FetchLibraryItemDetails
    original_new = service_class.method(:new)
    service_class.define_singleton_method(:new) { |*_arguments| service }

    get library_item_server_connection_url(@server_connection, "artist-id")

    assert_response :success
    assert_select "header.media-topbar[data-media-header-target='bar'] a[href='#{library_artists_path}']", 1
    assert_select "header.media-topbar .media-topbar__title", "Artist name"
    assert_select "header.listen-topbar", 0
    assert_select ".detail-back-link", count: 0
    assert_select ".detail-albums h2", "Albums"
    assert_select ".detail-albums__grid .listen-card h3", "Artist album"
    assert_select ".detail-albums__grid .listen-card__year", "2024"
    assert_select ".listen-section h2", { text: "More by this artist", count: 0 }
  ensure
    service_class.define_singleton_method(:new, original_new)
  end

  test "uses the stable library fallback for a playable detail page" do
    result = ServerConnections::FetchLibraryItemDetailsResultData.new(
      details: {
        item: { "Id" => "book-id", "Name" => "Book name", "Type" => "AudioBook" },
        album: { "Id" => "book-id", "Name" => "Book name" },
        kind: :audiobook,
        tracks: [],
        other_albums: [],
        similar_albums: []
      },
      access_token: "token",
      message: nil
    )
    service = Object.new
    service.define_singleton_method(:call) { result }
    service_class = ServerConnections::FetchLibraryItemDetails
    original_new = service_class.method(:new)
    service_class.define_singleton_method(:new) { |*_arguments| service }

    get library_item_server_connection_url(@server_connection, "book-id"), headers: { "Referer" => root_url }

    assert_response :success
    assert_select "header.media-topbar a[href='#{library_audiobooks_path}'][data-controller='history-back']", 1
  ensure
    service_class.define_singleton_method(:new, original_new)
  end

  test "hides play from start for an audiobook that has not been started" do
    result = ServerConnections::FetchLibraryItemDetailsResultData.new(
      details: {
        item: { "Id" => "new-book-id", "Name" => "New book", "Type" => "AudioBook", "RunTimeTicks" => 3_600_000_000, "UserData" => { "PlaybackPositionTicks" => 0 } },
        album: { "Id" => "new-book-id", "Name" => "New book" },
        kind: :audiobook,
        tracks: [],
        other_albums: [],
        similar_albums: []
      },
      access_token: "token",
      message: nil
    )
    service = Object.new
    service.define_singleton_method(:call) { result }
    service_class = ServerConnections::FetchLibraryItemDetails
    original_new = service_class.method(:new)
    service_class.define_singleton_method(:new) { |*_arguments| service }

    get library_item_server_connection_url(@server_connection, "new-book-id")

    assert_response :success
    assert_select "button[aria-label='Play New book']", 1
    assert_select "button[aria-label='Play New book from the beginning'][hidden]", 1
  ensure
    service_class.define_singleton_method(:new, original_new)
  end

  test "shows a selected song within its album context" do
    result = ServerConnections::FetchLibraryItemDetailsResultData.new(
      details: {
        item: { "Id" => "song-id", "Name" => "Selected song", "Type" => "Audio", "AlbumId" => "album-id" },
        album: { "Id" => "album-id", "Name" => "Album name", "AlbumArtist" => "Artist" },
        tracks: [ { "Id" => "song-id", "Name" => "Selected song" }, { "Id" => "other-song", "Name" => "Other song" } ],
        other_albums: [],
        similar_albums: []
      },
      access_token: "token",
      message: nil
    )
    service = Object.new
    service.define_singleton_method(:call) { result }
    service_class = ServerConnections::FetchLibraryItemDetails
    original_new = service_class.method(:new)
    service_class.define_singleton_method(:new) { |*_arguments| service }

    get library_item_server_connection_url(@server_connection, "song-id")

    assert_response :success
    assert_select ".detail-hero h1", "Album name"
    assert_select ".track-list li.is-selected strong", "Selected song"
    assert_select ".track-list li:not(.is-selected) strong", "Other song"
  ensure
    service_class.define_singleton_method(:new, original_new)
  end

  test "renders playlist details with playlist labels and track count" do
    result = ServerConnections::FetchLibraryItemDetailsResultData.new(
      details: {
        item: { "Id" => "playlist-id", "Name" => "Focus mix", "Type" => "Playlist", "Overview" => "Good for deep work" },
        album: { "Id" => "playlist-id", "Name" => "Focus mix", "Type" => "Playlist", "Overview" => "Good for deep work" },
        kind: :playlist,
        tracks: [ { "Id" => "track-1", "PlaylistItemId" => "entry-1", "Name" => "Intro", "RunTimeTicks" => 120_000_000 }, { "Id" => "track-2", "PlaylistItemId" => "entry-2", "Name" => "Loop", "RunTimeTicks" => 180_000_000 } ],
        other_albums: [],
        similar_albums: []
      },
      access_token: "token",
      message: nil
    )
    service = Object.new
    service.define_singleton_method(:call) { result }
    service_class = ServerConnections::FetchLibraryItemDetails
    original_new = service_class.method(:new)
    service_class.define_singleton_method(:new) { |*_arguments| service }

    get library_item_server_connection_url(@server_connection, "playlist-id")

    assert_response :success
    assert_select "header.media-topbar[data-media-header-target='bar'] a[href='#{library_playlists_path}']", 1
    assert_select ".detail-hero__kind", "Playlist"
    assert_select ".detail-hero__release", "2 tracks"
    assert_select ".detail-hero h1", "Focus mix"
    assert_select ".track-list--playlist li span", count: 0
    assert_select ".track-list__remove[data-card-options-remove-playlist-track-url-param='#{playlist_item_server_connection_path(@server_connection, playlist_id: "playlist-id", entry_id: "entry-1")}']"
  ensure
    service_class.define_singleton_method(:new, original_new)
  end
end
