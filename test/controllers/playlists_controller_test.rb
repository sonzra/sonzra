require "test_helper"

class PlaylistsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @server_connection = ServerConnection.create!(
      media_server: MediaServer.create!(name: "Home server", provider: :jellyfin, base_url: "https://jellyfin.example.com"),
      username: "bruno",
      password: "secret",
      user: users(:one)
    )
  end

  test "adds a track to a playlist" do
    client = Object.new
    captured_arguments = nil
    client.define_singleton_method(:add_to_playlist) do |playlist_id:, item_ids: nil, item_id: nil|
      captured_arguments = { playlist_id:, item_ids:, item_id: }
    end

    with_jellyfin_client(client) do
      post playlist_items_server_connection_url(@server_connection, playlist_id: "playlist-1"),
        params: { item_id: "track-1" },
        as: :json
    end

    assert_response :no_content
    assert_equal({ playlist_id: "playlist-1", item_ids: [ "track-1" ], item_id: nil }, captured_arguments)
  end

  test "adds all album tracks to a playlist" do
    client = Object.new
    captured_arguments = nil
    requested_album_id = nil
    client.define_singleton_method(:playback_queue) do |item_id|
      requested_album_id = item_id
      Integrations::PlaybackQueueResponseData.new(
        items: [ { "Id" => "track-1" }, { "Id" => "track-2" } ],
        access_token: "token"
      )
    end
    client.define_singleton_method(:add_to_playlist) do |playlist_id:, item_ids: nil, item_id: nil|
      captured_arguments = { playlist_id:, item_ids:, item_id: }
    end
    client.define_singleton_method(:resolved_user_id) { "user-id" }

    with_jellyfin_client(client) do
      post playlist_items_server_connection_url(@server_connection, playlist_id: "playlist-1"),
        params: { item_id: "album-1", item_type: "MusicAlbum" },
        as: :json
    end

    assert_response :no_content
    assert_equal "album-1", requested_album_id
    assert_equal({ playlist_id: "playlist-1", item_ids: [ "track-1", "track-2" ], item_id: nil }, captured_arguments)
  end

  test "adds all artist discography tracks to a playlist" do
    client = Object.new
    captured_arguments = nil
    requested_artist_id = nil
    client.define_singleton_method(:artist_track_ids) do |artist_id|
      requested_artist_id = artist_id
      [ "artist-track-1", "artist-track-2", "artist-track-3" ]
    end
    client.define_singleton_method(:add_to_playlist) do |playlist_id:, item_ids: nil, item_id: nil|
      captured_arguments = { playlist_id:, item_ids:, item_id: }
    end

    with_jellyfin_client(client) do
      post playlist_items_server_connection_url(@server_connection, playlist_id: "playlist-1"),
        params: { item_id: "artist-42", item_type: "MusicArtist" },
        as: :json
    end

    assert_response :no_content
    assert_equal "artist-42", requested_artist_id
    assert_equal({ playlist_id: "playlist-1", item_ids: [ "artist-track-1", "artist-track-2", "artist-track-3" ], item_id: nil }, captured_arguments)
  end

  test "adds all recommendation collection tracks to a playlist" do
    client = Object.new
    captured_arguments = nil
    client.define_singleton_method(:add_to_playlist) do |playlist_id:, item_ids: nil, item_id: nil|
      captured_arguments = { playlist_id:, item_ids:, item_id: }
    end
    collection = users(:one).recommendation_collections.create!(
      server_connection: @server_connection,
      strategy: :friday_rediscovery,
      title: "Friday Discovery",
      subtitle: "Weekly mix",
      period_date: Date.current,
      generated_at: Time.current
    )
    collection.recommendation_tracks.create!(item_id: "rec-track-1", title: "Song 1", artist: "Artist 1", position: 1)
    collection.recommendation_tracks.create!(item_id: "rec-track-2", title: "Song 2", artist: "Artist 2", position: 2)

    with_jellyfin_client(client) do
      post playlist_items_server_connection_url(@server_connection, playlist_id: "playlist-1"),
        params: { item_id: collection.id, item_type: "RecommendationCollection" },
        as: :json
    end

    assert_response :no_content
    assert_equal({ playlist_id: "playlist-1", item_ids: [ "rec-track-1", "rec-track-2" ], item_id: nil }, captured_arguments)
  end

  test "creates a playlist and returns its id as json" do
    client = Object.new
    client.define_singleton_method(:create_playlist) { |name| "playlist-9" if name == "Road trip" }

    with_jellyfin_client(client) do
      post playlists_server_connection_url(@server_connection),
        params: { name: "Road trip" },
        as: :json
    end

    assert_response :created
    assert_equal({ "id" => "playlist-9", "item_included" => false }, JSON.parse(response.body))
  end

  test "deletes a playlist" do
    client = Object.new
    deleted_playlist_id = nil
    client.define_singleton_method(:delete_playlist) do |playlist_id:|
      deleted_playlist_id = playlist_id
    end

    with_jellyfin_client(client) do
      delete playlist_server_connection_url(@server_connection, "playlist-7"), as: :json
    end

    assert_response :no_content
    assert_equal "playlist-7", deleted_playlist_id
  end

  test "returns a helpful message when Jellyfin refuses to delete a playlist" do
    client = Object.new
    client.define_singleton_method(:delete_playlist) do |playlist_id:|
      raise Integrations::Jellyfin::Client::ConnectionError, "The server returned HTTP 405."
    end

    with_jellyfin_client(client) do
      delete playlist_server_connection_url(@server_connection, "playlist-7"), as: :json
    end

    assert_response :bad_gateway
    assert_match "managed outside Sonzra", JSON.parse(response.body).fetch("error")
  end

  test "removes a song from a playlist" do
    client = Object.new
    removed_arguments = nil
    client.define_singleton_method(:remove_from_playlist) do |playlist_id:, entry_id:|
      removed_arguments = { playlist_id:, entry_id: }
    end

    with_jellyfin_client(client) do
      delete playlist_item_server_connection_url(@server_connection, playlist_id: "playlist-1", entry_id: "entry-7"), as: :json
    end

    assert_response :no_content
    assert_equal({ playlist_id: "playlist-1", entry_id: "entry-7" }, removed_arguments)
  end

  test "broadcasts live sync removal when collaborative capability is supported" do
    client = Object.new
    client.define_singleton_method(:supports?) { |cap| cap == Integrations::Capabilities::COLLABORATIVE_PLAYLISTS }
    client.define_singleton_method(:remove_from_playlist) { |playlist_id:, entry_id:| true }

    broadcasted = []
    singleton = Turbo::StreamsChannel.singleton_class
    orig_remove = Turbo::StreamsChannel.method(:broadcast_remove_to)
    singleton.define_method(:broadcast_remove_to) do |stream, **options|
      broadcasted << { stream: stream, **options }
    end

    begin
      with_jellyfin_client(client) do
        delete playlist_item_server_connection_url(@server_connection, playlist_id: "playlist-1", entry_id: "entry-7"), as: :json
      end
    ensure
      singleton.define_method(:broadcast_remove_to, orig_remove)
    end

    assert_response :no_content
    assert_equal 1, broadcasted.size
    assert_equal "playlist_#{@server_connection.media_server_id}_playlist-1", broadcasted.first[:stream]
    assert_equal "playlist_entry_entry-7", broadcasted.first[:target]
  end

  test "broadcasts live sync addition when collaborative capability is supported" do
    client = Object.new
    client.define_singleton_method(:supports?) { |cap| cap == Integrations::Capabilities::COLLABORATIVE_PLAYLISTS }
    client.define_singleton_method(:add_to_playlist) { |**| true }
    client.define_singleton_method(:library_item_details) do |_|
      Integrations::LibraryItemDetailsResponseData.new(
        details: {
          album: { "Id" => "playlist-1", "Name" => "Party Mix" },
          tracks: [ { "Id" => "track-10", "Name" => "Dance Track", "RunTimeTicks" => 1800000000, "PlaylistItemId" => "entry-10" } ]
        },
        access_token: "token"
      )
    end

    broadcasted = []
    singleton = Turbo::StreamsChannel.singleton_class
    orig_append = Turbo::StreamsChannel.method(:broadcast_append_to)
    singleton.define_method(:broadcast_append_to) do |stream, **options|
      broadcasted << { stream: stream, **options }
    end

    begin
      with_jellyfin_client(client) do
        post playlist_items_server_connection_url(@server_connection, playlist_id: "playlist-1"),
             params: { item_id: "track-10" },
             as: :json
      end
    ensure
      singleton.define_method(:broadcast_append_to, orig_append)
    end

    assert_response :no_content
    assert_equal 1, broadcasted.size
    assert_equal "playlist_#{@server_connection.media_server_id}_playlist-1", broadcasted.first[:stream]
    assert_equal "playlist_tracks_playlist-1", broadcasted.first[:target]
  end

  private

  def with_jellyfin_client(client)
    client_class = Integrations::Jellyfin::Client
    client_class.singleton_class.alias_method :new_before_playlists_test, :new
    client_class.define_singleton_method(:new) { |**| client }
    yield
  ensure
    client_class.singleton_class.alias_method :new, :new_before_playlists_test
    client_class.singleton_class.remove_method :new_before_playlists_test
  end
end
