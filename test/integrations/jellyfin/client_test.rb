require "test_helper"

class Integrations::Jellyfin::ClientTest < ActiveSupport::TestCase
  class FakeHttp
    attr_reader :last_request, :requests

    def initialize(response)
      @responses = Array(response)
      @requests = []
    end

    def start(...)
      yield self
    end

    def request(request)
      @last_request = request
      @requests << request
      response = @responses.shift
      block_given? ? yield(response) : response
    end
  end

  test "authenticates with the server credentials" do
    response = Net::HTTPOK.new("1.1", "200", "OK")
    response.instance_variable_set(:@read, true)
    response.body = { User: { Name: "Bruno" } }.to_json
    http = FakeHttp.new(response)

    user_name = Integrations::Jellyfin::Client.new(
      base_url: "https://example.com/jellyfin",
      username: "bruno",
      password: "secret",
      http: http
    ).authenticate

    assert_equal "Bruno", user_name
    assert_equal "/jellyfin/Users/AuthenticateByName", http.last_request.path
    assert_equal({ "Username" => "bruno", "Pw" => "secret" }, JSON.parse(http.last_request.body))
  end

  test "initiates and completes Quick Connect without a password" do
    initiate_response = Net::HTTPOK.new("1.1", "200", "OK")
    initiate_response.instance_variable_set(:@read, true)
    initiate_response.body = { Secret: "secret", Code: "ABC123" }.to_json
    state_response = Net::HTTPOK.new("1.1", "200", "OK")
    state_response.instance_variable_set(:@read, true)
    state_response.body = { Authenticated: true }.to_json
    authentication_response = Net::HTTPOK.new("1.1", "200", "OK")
    authentication_response.instance_variable_set(:@read, true)
    authentication_response.body = { AccessToken: "access-token", User: { Name: "Bruno" } }.to_json
    http = FakeHttp.new([ initiate_response, state_response, authentication_response ])
    client = Integrations::Jellyfin::Client.new(base_url: "https://example.com", http: http)

    assert_equal "ABC123", client.initiate_quick_connect.fetch("Code")
    assert client.quick_connect_state("secret").fetch("Authenticated")
    assert_equal "access-token", client.authenticate_with_quick_connect("secret").fetch("AccessToken")
    assert_equal "/QuickConnect/Initiate", http.requests.first.path
    assert_equal "/QuickConnect/Connect?secret=secret", http.requests.second.path
    assert_equal "/Users/AuthenticateWithQuickConnect", http.requests.third.path
    assert_equal({ "Secret" => "secret" }, JSON.parse(http.requests.third.body))
  end

  test "fetches most-played songs and albums for the home screen" do
    authentication_response = Net::HTTPOK.new("1.1", "200", "OK")
    authentication_response.instance_variable_set(:@read, true)
    authentication_response.body = { AccessToken: "token", User: { Id: "user-id", Name: "Bruno" } }.to_json
    collection_responses = Array.new(11) do
      Net::HTTPOK.new("1.1", "200", "OK").tap do |response|
        response.instance_variable_set(:@read, true)
        response.body = { Items: [] }.to_json
      end
    end
    http = FakeHttp.new([ authentication_response, *collection_responses ])

    Integrations::Jellyfin::Client.new(base_url: "https://example.com", username: "bruno", password: "secret", http: http).home_content

    item_requests = http.requests.select { |request| URI.parse(request.path).path == "/Users/user-id/Items" }
    most_played_requests = item_requests.select do |request|
      URI.decode_www_form(URI.parse(request.path).query).to_h["SortBy"] == "PlayCount"
    end
    most_played_types = most_played_requests.map do |request|
      URI.decode_www_form(URI.parse(request.path).query).to_h["IncludeItemTypes"]
    end
    most_played_user_data = most_played_requests.map do |request|
      URI.decode_www_form(URI.parse(request.path).query).to_h["EnableUserData"]
    end

    assert_equal [ "Audio", "MusicAlbum" ], most_played_types
    assert_equal [ "true", "true" ], most_played_user_data
    assert_includes URI.decode_www_form(URI.parse(most_played_requests.first.path).query).to_h["Fields"], "Genres"
    podcast_request = item_requests.find do |request|
      URI.decode_www_form(URI.parse(request.path).query).to_h["SortBy"] == "DateCreated"
    end
    assert_equal "8", URI.decode_www_form(URI.parse(podcast_request.path).query).to_h["Limit"]
  end

  test "keeps podcasts out of album shelves and exposes dedicated podcast and audiobook shelves" do
    response = lambda do |body|
      Net::HTTPOK.new("1.1", "200", "OK").tap do |http_response|
        http_response.instance_variable_set(:@read, true)
        http_response.body = body.to_json
      end
    end
    authentication_response = response.call(AccessToken: "token", User: { Id: "user-id", Name: "Bruno" })
    responses = [
      response.call(Items: [ { Id: "podcast-library", Name: "Podcasts" } ]),
      response.call(Items: [ { Id: "podcast-series", Name: "Podcast series", ParentId: "podcast-library" } ]),
      response.call(Items: [ { Id: "song-id", Name: "Played song", Type: "Audio", Genres: [ "Rock" ] }, { Id: "podcast-id", Name: "Podcast episode", Type: "Audio", Genres: [ "Talk" ] } ]),
      response.call(Items: [ { Id: "podcast-id", Name: "Podcast episode", Type: "Audio" } ]),
      response.call(Items: [ { Id: "audiobook-id", Name: "Audio book", Type: "AudioBook", UserData: { PlaybackPositionTicks: 120_000_000 } } ]),
      response.call(Items: [ { Id: "podcast-id", Name: "Podcast episode", Type: "Audio", UserData: { PlaybackPositionTicks: 90_000_000 } } ]),
      response.call(Items: [ { Id: "podcast-series", Name: "Podcast series", ParentId: "podcast-library" }, { Id: "album-id", Name: "Music album", ParentId: "music-library" } ]),
      response.call(Items: []),
      response.call(Items: []),
      response.call(Items: [ { Id: "song-id", Name: "Played song", AlbumId: "music-album", Genres: [ "Rock", "Pop" ], UserData: { PlayCount: 3 } }, { Id: "podcast-id", Name: "Podcast episode", AlbumId: "podcast-series", Genres: [ "Talk" ], UserData: { PlayCount: 5 } } ]),
      response.call(Items: [ { Id: "podcast-series", Name: "Podcast series", ParentId: "podcast-library", UserData: { PlayCount: 4 } }, { Id: "album-id", Name: "Music album", ParentId: "music-library", UserData: { PlayCount: 2 } } ]),
      response.call(Items: [ { Id: "audiobook-id", Name: "Audio book", Type: "AudioBook" } ]),
      response.call(Items: [ { Id: "podcast-id", Name: "Podcast episode", Type: "Audio" } ])
    ]
    http = FakeHttp.new([ authentication_response, *responses ])

    content = Integrations::Jellyfin::Client.new(base_url: "https://example.com", username: "bruno", password: "secret", http: http).home_content.content

    assert_equal [ "Music album" ], content[:recently_added_albums].pluck("Name")
    assert_equal [ "Played song" ], content[:recently_played].pluck("Name")
    assert_equal [ "Played song" ], content[:most_played_songs].pluck("Name")
    assert_equal [ "Rock", "Pop" ], content[:genres].pluck("Name")
    assert_equal [ "Music album" ], content[:most_played_albums].pluck("Name")
    assert_equal [ "Audio book" ], content[:continue_audiobooks].pluck("Name")
    assert_equal [ "Podcast episode" ], content[:continue_podcasts].pluck("Name")
    assert_equal [ "Audio book" ], content[:recently_added_audiobooks].pluck("Name")
    assert_equal [ "Podcast episode" ], content[:recently_added_podcasts].pluck("Name")

    resume_requests = http.requests.select { |request| URI.parse(request.path).path == "/Users/user-id/Items/Resume" }
    assert_equal [ "AudioBook", "Audio" ], resume_requests.map { |request| URI.decode_www_form(URI.parse(request.path).query).to_h["IncludeItemTypes"] }
    assert_equal "podcast-library", URI.decode_www_form(URI.parse(resume_requests.last.path).query).to_h["ParentId"]
  end

  test "filters podcast albums and non-album results from music recommendations" do
    client = Integrations::Jellyfin::Client.new(base_url: "https://example.com", username: "bruno", password: "secret")
    recommendations = [
      { "Id" => "music-album", "Type" => "MusicAlbum", "ParentId" => "music-library" },
      { "Id" => "podcast-album", "Type" => "MusicAlbum", "ParentId" => "podcast-library" },
      { "Id" => "podcast-episode", "Type" => "Audio" }
    ]

    music_albums = recommendations.select { |item| item["Type"] == "MusicAlbum" }
    filtered = client.send(:music_albums_without_podcasts, music_albums, { "Id" => "podcast-library" }, [ "podcast-album" ])

    assert_equal [ "music-album" ], filtered.pluck("Id")
  end

  test "keeps the recently played music shelf within the last six hours" do
    client = Integrations::Jellyfin::Client.new(base_url: "https://example.com", username: "bruno", password: "secret")
    now = Time.zone.parse("2026-08-04 12:00:00")
    items = [
      { "Id" => "recent-song", "AlbumId" => "music-album", "UserData" => { "LastPlayedDate" => (now - 5.hours).iso8601 } },
      { "Id" => "old-song", "AlbumId" => "music-album", "UserData" => { "LastPlayedDate" => (now - 7.hours).iso8601 } },
      { "Id" => "timestamp-less-song", "AlbumId" => "music-album", "UserData" => {} },
      { "Id" => "podcast", "AlbumId" => "podcast-album", "UserData" => { "LastPlayedDate" => (now - 1.hour).iso8601 } }
    ]

    travel_to(now) do
      recent_items = client.send(:recently_played_music, items, [ "podcast-album" ])

      assert_equal [ "recent-song", "timestamp-less-song" ], recent_items.pluck("Id")
    end
  end

  test "sorts an artist's albums by release date with metadata fallbacks" do
    response = Net::HTTPOK.new("1.1", "200", "OK")
    response.instance_variable_set(:@read, true)
    response.body = {
      Items: [
        { Id: "old", Name: "Old", ProductionYear: 1999 },
        { Id: "new", Name: "New", PremiereDate: "2024-06-01T00:00:00.0000000Z" },
        { Id: "middle", Name: "Middle", ProductionYear: 2010 }
      ],
      TotalRecordCount: 3
    }.to_json
    http = FakeHttp.new(response)
    client = Integrations::Jellyfin::Client.new(base_url: "https://example.com", username: "bruno", password: "secret", http: http)

    albums = client.send(:artist_albums, "user-id", "token", "artist-id")

    parameters = URI.decode_www_form(URI.parse(http.last_request.path).query).to_h
    assert_equal "PremiereDate", parameters["SortBy"]
    assert_equal "Descending", parameters["SortOrder"]
    assert_equal [ "new", "middle", "old" ], albums.pluck("Id")
  end

  test "fetches an instant mix for radio playback" do
    authentication_response = Net::HTTPOK.new("1.1", "200", "OK")
    authentication_response.instance_variable_set(:@read, true)
    authentication_response.body = { AccessToken: "token", User: { Id: "user-id", Name: "Bruno" } }.to_json
    mix_response = Net::HTTPOK.new("1.1", "200", "OK")
    mix_response.instance_variable_set(:@read, true)
    mix_response.body = { Items: [ { Id: "track-1", Type: "Audio" }, { Id: "album-1", Type: "MusicAlbum" } ] }.to_json
    http = FakeHttp.new([ authentication_response, mix_response ])

    response = Integrations::Jellyfin::Client.new(
      base_url: "https://example.com",
      username: "bruno",
      password: "secret",
      http: http
    ).instant_mix("seed-track", limit: 10)

    parameters = URI.decode_www_form(URI.parse(http.last_request.path).query).to_h
    assert_equal "/Songs/seed-track/InstantMix", URI.parse(http.last_request.path).path
    assert_equal "user-id", parameters["UserId"]
    assert_equal "10", parameters["Limit"]
    assert_equal [ "track-1" ], response.items.pluck("Id")
  end

  test "builds Friday Rediscovery from unplayed and long-unheard library tracks" do
    response = lambda do |body|
      Net::HTTPOK.new("1.1", "200", "OK").tap do |http_response|
        http_response.instance_variable_set(:@read, true)
        http_response.body = body.to_json
      end
    end
    authentication_response = response.call(AccessToken: "token", User: { Id: "user-id", Name: "Bruno" })
    podcast_library_response = response.call(Items: [ { Id: "podcast-library", Name: "Podcasts" } ])
    podcast_albums_response = response.call(Items: [ { Id: "podcast-album" } ])
    unplayed_response = response.call(Items: [
      { Id: "unplayed", Name: "Never played", UserData: {} },
      { Id: "podcast", Name: "Podcast episode", AlbumId: "podcast-album", UserData: {} }
    ])
    long_unheard_response = response.call(Items: [
      { Id: "old", Name: "Long unheard", UserData: { LastPlayedDate: "2026-07-01T12:00:00Z" } },
      { Id: "recent", Name: "Recently played", UserData: { LastPlayedDate: "2026-08-10T12:00:00Z" } }
    ])
    http = FakeHttp.new([ authentication_response, podcast_library_response, podcast_albums_response, unplayed_response, long_unheard_response ])

    tracks = Integrations::Jellyfin::Client.new(base_url: "https://example.com", username: "bruno", password: "secret", http: http)
      .recommendation_tracks("friday_rediscovery", Date.new(2026, 8, 14))

    unplayed_parameters = URI.decode_www_form(URI.parse(http.requests[3].path).query).to_h
    long_unheard_parameters = URI.decode_www_form(URI.parse(http.requests[4].path).query).to_h
    assert_equal [ "unplayed", "old" ], tracks.pluck("Id")
    assert_equal "false", unplayed_parameters["IsPlayed"]
    assert_equal "Random", unplayed_parameters["SortBy"]
    assert_equal "true", long_unheard_parameters["IsPlayed"]
    assert_equal "DatePlayed", long_unheard_parameters["SortBy"]
    assert_equal "Ascending", long_unheard_parameters["SortOrder"]
    assert_equal "200", long_unheard_parameters["Limit"]
  end

  test "builds Top of the Month from Jellyfin playback activity" do
    response = lambda do |body|
      Net::HTTPOK.new("1.1", "200", "OK").tap do |http_response|
        http_response.instance_variable_set(:@read, true)
        http_response.body = body.to_json
      end
    end
    authentication_response = response.call(AccessToken: "token", User: { Id: "user-id", Name: "Bruno" })
    activity_response = response.call(Items: [
      { UserId: "user-id", Type: "AudioPlayback", Date: "2026-08-11T12:00:00Z", Name: "Bruno is playing Artist - Monthly track on Sonzra" },
      { UserId: "user-id", Type: "AudioPlayback", Date: "2026-07-31T12:00:00Z", Name: "Bruno is playing Artist - Older track on Sonzra" }
    ])
    podcast_library_response = response.call(Items: [])
    track_response = response.call(Items: [ { Id: "track-id", Name: "Monthly track", AlbumArtist: "Artist", Type: "Audio" } ])
    http = FakeHttp.new([ authentication_response, activity_response, podcast_library_response, track_response ])

    tracks = Integrations::Jellyfin::Client.new(base_url: "https://example.com", username: "bruno", password: "secret", http: http)
      .monthly_top_tracks(Date.new(2026, 8, 31))

    assert_equal [ "track-id" ], tracks.pluck("Id")
    assert_equal "/System/ActivityLog/Entries", URI.parse(http.requests[1].path).path
    assert_equal "Monthly track", URI.decode_www_form(URI.parse(http.requests[3].path).query).to_h["SearchTerm"]
  end

  test "fetches stored lyrics and treats a missing lyric document as unavailable" do
    authentication_response = Net::HTTPOK.new("1.1", "200", "OK")
    authentication_response.instance_variable_set(:@read, true)
    authentication_response.body = { AccessToken: "token", User: { Id: "user-id", Name: "Bruno" } }.to_json
    lyrics_response = Net::HTTPOK.new("1.1", "200", "OK")
    lyrics_response.instance_variable_set(:@read, true)
    lyrics_response.body = { Lyrics: [ { Text: "A timed line", Start: 15_000_000 } ] }.to_json
    missing_response = Net::HTTPNotFound.new("1.1", "404", "Not Found")
    http = FakeHttp.new([ authentication_response, lyrics_response, authentication_response, missing_response ])
    client = Integrations::Jellyfin::Client.new(base_url: "https://example.com", username: "bruno", password: "secret", http: http)

    lyrics = client.lyrics("track-id")
    missing = client.lyrics("missing-track")

    assert_equal "/Audio/track-id/Lyrics", http.requests[1].path
    assert_equal "A timed line", lyrics.lines.first.fetch("Text")
    assert lyrics.available
    assert_not missing.available
    assert_empty missing.lines
  end

  test "raises an authentication error for rejected credentials" do
    response = Net::HTTPUnauthorized.new("1.1", "401", "Unauthorized")
    http = FakeHttp.new(response)
    client = Integrations::Jellyfin::Client.new(
      base_url: "https://example.com",
      username: "bruno",
      password: "wrong",
      http: http
    )

    assert_raises(Integrations::Jellyfin::Client::AuthenticationError) { client.authenticate }
  end

  test "fetches an artwork image with the supplied access token" do
    response = Net::HTTPOK.new("1.1", "200", "OK")
    response.instance_variable_set(:@read, true)
    response.body = "image-data"
    response["Content-Type"] = "image/webp"
    http = FakeHttp.new(response)

    artwork = Integrations::Jellyfin::Client.new(base_url: "https://example.com", username: "bruno", password: "secret", http: http).artwork(
      item_id: "album-id",
      tag: "image-tag",
      access_token: "token"
    )

    assert_equal "image-data", artwork.body
    assert_equal "image/webp", artwork.content_type
    assert_equal "token", http.last_request["X-Emby-Token"]
  end

  test "streams browser-compatible audio and forwards a byte range" do
    audio_response = Net::HTTPPartialContent.new("1.1", "206", "Partial Content")
    audio_response.instance_variable_set(:@read, true)
    audio_response.body = "audio-data"
    audio_response["Content-Type"] = "audio/flac"
    audio_response["Accept-Ranges"] = "bytes"
    audio_response["Content-Length"] = "10"
    audio_response["Content-Range"] = "bytes 10-19/100"
    audio_response.define_singleton_method(:read_body) { |&block| block.call("audio-data") }
    http = FakeHttp.new(audio_response)

    parts = []
    Integrations::Jellyfin::Client.new(base_url: "https://example.com", username: "bruno", password: "secret", http: http).stream_audio(item_id: "track-id", range: "bytes=10-", access_token: "token") { |part| parts << part }
    stream = parts.first

    assert_equal "audio-data", parts.last
    assert_equal "audio/flac", stream.content_type
    assert_equal 206, stream.status
    assert_equal "/Audio/track-id/stream?Static=true", http.last_request.path
    assert_equal "bytes=10-", http.last_request["Range"]
    assert_equal "token", http.last_request["X-Emby-Token"]
  end

  test "reports playback progress with the supplied access token" do
    response = Net::HTTPNoContent.new("1.1", "204", "No Content")
    http = FakeHttp.new(response)

    result = Integrations::Jellyfin::Client.new(base_url: "https://example.com", username: "bruno", password: "secret", http: http).report_playback(
      event: "progress",
      item_id: "track-id",
      position_ticks: 32_100_000,
      paused: true,
      access_token: "token"
    )

    assert_equal "token", result.access_token
    assert_equal "/Sessions/Playing/Progress", http.last_request.path
    assert_equal "token", http.last_request["X-Emby-Token"]
    assert_equal({ "ItemId" => "track-id", "PositionTicks" => 32_100_000, "CanSeek" => true, "IsPaused" => true, "PlayMethod" => "DirectPlay" }, JSON.parse(http.last_request.body))
  end

  test "adds a track to a playlist for the authenticated user" do
    authentication_response = Net::HTTPOK.new("1.1", "200", "OK")
    authentication_response.instance_variable_set(:@read, true)
    authentication_response.body = { AccessToken: "token", User: { Id: "user-id", Name: "Bruno" } }.to_json
    response = Net::HTTPNoContent.new("1.1", "204", "No Content")
    http = FakeHttp.new([ authentication_response, response ])

    Integrations::Jellyfin::Client.new(base_url: "https://example.com", username: "bruno", password: "secret", http: http).add_to_playlist(
      playlist_id: "playlist-1",
      item_id: "track-1"
    )

    assert_equal "/Playlists/playlist-1/Items?Ids=track-1&UserId=user-id", http.last_request.path
    assert_equal "token", http.last_request["X-Emby-Token"]
  end

  test "adds multiple tracks to a playlist for the authenticated user" do
    authentication_response = Net::HTTPOK.new("1.1", "200", "OK")
    authentication_response.instance_variable_set(:@read, true)
    authentication_response.body = { AccessToken: "token", User: { Id: "user-id", Name: "Bruno" } }.to_json
    response = Net::HTTPNoContent.new("1.1", "204", "No Content")
    http = FakeHttp.new([ authentication_response, response ])

    Integrations::Jellyfin::Client.new(base_url: "https://example.com", username: "bruno", password: "secret", http: http).add_to_playlist(
      playlist_id: "playlist-1",
      item_ids: [ "track-1", "track-2" ]
    )

    assert_equal "/Playlists/playlist-1/Items?Ids=track-1%2Ctrack-2&UserId=user-id", http.last_request.path
    assert_equal "token", http.last_request["X-Emby-Token"]
  end

  test "deletes a playlist item by id" do
    authentication_response = Net::HTTPOK.new("1.1", "200", "OK")
    authentication_response.instance_variable_set(:@read, true)
    authentication_response.body = { AccessToken: "token", User: { Id: "user-id", Name: "Bruno" } }.to_json
    response = Net::HTTPNoContent.new("1.1", "204", "No Content")
    http = FakeHttp.new([ authentication_response, response ])

    Integrations::Jellyfin::Client.new(base_url: "https://example.com", username: "bruno", password: "secret", http: http).delete_playlist(
      playlist_id: "playlist-7"
    )

    assert_equal "/Items/playlist-7", http.last_request.path
    assert_equal "token", http.last_request["X-Emby-Token"]
  end

  test "removes a playlist entry by id" do
    authentication_response = Net::HTTPOK.new("1.1", "200", "OK")
    authentication_response.instance_variable_set(:@read, true)
    authentication_response.body = { AccessToken: "token", User: { Id: "user-id", Name: "Bruno" } }.to_json
    response = Net::HTTPNoContent.new("1.1", "204", "No Content")
    http = FakeHttp.new([ authentication_response, response ])

    Integrations::Jellyfin::Client.new(base_url: "https://example.com", username: "bruno", password: "secret", http: http).remove_from_playlist(
      playlist_id: "playlist-1",
      entry_id: "entry-7"
    )

    assert_equal "/Playlists/playlist-1/Items?EntryIds=entry-7", http.last_request.path
    assert_equal "token", http.last_request["X-Emby-Token"]
  end

  test "reuses a cached remote user id with an access token" do
    response = Net::HTTPNoContent.new("1.1", "204", "No Content")
    http = FakeHttp.new(response)
    client = Integrations::Jellyfin::Client.new(
      base_url: "https://example.com",
      username: "Bruno",
      access_token: "token",
      remote_user_id: "user-id",
      http: http
    )

    client.delete_playlist(playlist_id: "playlist-7")

    assert_equal 1, http.requests.size
    assert_equal "/Items/playlist-7", http.last_request.path
    assert_equal "user-id", client.resolved_user_id
  end

  test "updates a resumable item's saved position" do
    response = Net::HTTPOK.new("1.1", "200", "OK")
    http = FakeHttp.new(response)

    result = Integrations::Jellyfin::Client.new(base_url: "https://example.com", username: "bruno", password: "secret", http: http).update_playback_position(
      item_id: "podcast-id",
      position_ticks: 200_000_000,
      access_token: "token"
    )

    assert_equal "token", result.access_token
    assert_equal "/UserItems/podcast-id/UserData", http.last_request.path
    assert_equal({ "PlaybackPositionTicks" => 200_000_000, "Played" => false }, JSON.parse(http.last_request.body))
  end

  test "fetches only audiobook items for the audiobook collection" do
    authentication_response = Net::HTTPOK.new("1.1", "200", "OK")
    authentication_response.instance_variable_set(:@read, true)
    authentication_response.body = { AccessToken: "token", User: { Id: "user-id" } }.to_json
    collection_response = Net::HTTPOK.new("1.1", "200", "OK")
    collection_response.instance_variable_set(:@read, true)
    collection_response.body = { Items: [], TotalRecordCount: 0 }.to_json
    http = FakeHttp.new([ authentication_response, collection_response ])

    Integrations::Jellyfin::Client.new(base_url: "https://example.com", username: "bruno", password: "secret", http: http).library_collection(:audiobooks, page: 1, query: nil)

    parameters = URI.decode_www_form(URI.parse(http.last_request.path).query).to_h
    assert_equal "/Users/user-id/Items", URI.parse(http.last_request.path).path
    assert_equal "AudioBook", parameters["IncludeItemTypes"]
    assert_equal "SortName", parameters["SortBy"]
  end

  test "fetches recently played music in descending playback order" do
    response = lambda do |body|
      Net::HTTPOK.new("1.1", "200", "OK").tap do |http_response|
        http_response.instance_variable_set(:@read, true)
        http_response.body = body.to_json
      end
    end
    http = FakeHttp.new([
      response.call(AccessToken: "token", User: { Id: "user-id" }),
      response.call(Items: []),
      response.call(Items: [], TotalRecordCount: 0)
    ])

    Integrations::Jellyfin::Client.new(base_url: "https://example.com", username: "bruno", password: "secret", http: http).library_collection(:recently_played, page: 1, query: nil)

    parameters = URI.decode_www_form(URI.parse(http.last_request.path).query).to_h
    assert_equal "Audio", parameters["IncludeItemTypes"]
    assert_equal "DatePlayed", parameters["SortBy"]
    assert_equal "Descending", parameters["SortOrder"]
  end

  test "filters album collections by genre" do
    authentication_response = Net::HTTPOK.new("1.1", "200", "OK")
    authentication_response.instance_variable_set(:@read, true)
    authentication_response.body = { AccessToken: "token", User: { Id: "user-id" } }.to_json
    collection_response = Net::HTTPOK.new("1.1", "200", "OK")
    collection_response.instance_variable_set(:@read, true)
    collection_response.body = { Items: [], TotalRecordCount: 0 }.to_json
    http = FakeHttp.new([ authentication_response, collection_response ])

    Integrations::Jellyfin::Client.new(base_url: "https://example.com", username: "bruno", password: "secret", http: http).library_collection(:albums, page: 1, query: nil, genre: "Ambient")

    parameters = URI.decode_www_form(URI.parse(http.last_request.path).query).to_h
    assert_equal "Ambient", parameters["Genres"]
    assert_equal "MusicAlbum", parameters["IncludeItemTypes"]
  end

  test "fetches podcast shows from the podcast library" do
    authentication_response = Net::HTTPOK.new("1.1", "200", "OK")
    authentication_response.instance_variable_set(:@read, true)
    authentication_response.body = { AccessToken: "token", User: { Id: "user-id" } }.to_json
    views_response = Net::HTTPOK.new("1.1", "200", "OK")
    views_response.instance_variable_set(:@read, true)
    views_response.body = { Items: [ { Id: "podcast-library", Name: "My Podcasts" } ] }.to_json
    collection_response = Net::HTTPOK.new("1.1", "200", "OK")
    collection_response.instance_variable_set(:@read, true)
    collection_response.body = { Items: [], TotalRecordCount: 0 }.to_json
    http = FakeHttp.new([ authentication_response, views_response, collection_response ])

    Integrations::Jellyfin::Client.new(base_url: "https://example.com", username: "bruno", password: "secret", http: http).library_collection(:podcasts, page: 1, query: nil)

    parameters = URI.decode_www_form(URI.parse(http.last_request.path).query).to_h
    assert_equal "/Users/user-id/Items", URI.parse(http.last_request.path).path
    assert_equal "podcast-library", parameters["ParentId"]
    assert_equal "MusicAlbum", parameters["IncludeItemTypes"]
    assert_equal "true", parameters["Recursive"]
  end

  test "fetches the complete music genre directory" do
    authentication_response = Net::HTTPOK.new("1.1", "200", "OK")
    authentication_response.instance_variable_set(:@read, true)
    authentication_response.body = { AccessToken: "token", User: { Id: "user-id" } }.to_json
    genres_response = Net::HTTPOK.new("1.1", "200", "OK")
    genres_response.instance_variable_set(:@read, true)
    genres_response.body = { Items: [], TotalRecordCount: 0 }.to_json
    http = FakeHttp.new([ authentication_response, genres_response ])

    Integrations::Jellyfin::Client.new(base_url: "https://example.com", username: "bruno", password: "secret", http: http).library_collection(:genres, page: 1, query: "Ambient")

    request = http.last_request
    parameters = URI.decode_www_form(URI.parse(request.path).query).to_h
    assert_equal "/MusicGenres", URI.parse(request.path).path
    assert_equal "1000", parameters["Limit"]
    assert_equal "Ambient", parameters["SearchTerm"]
  end

  test "expands an album into tracks sorted by track number" do
    authentication_response = Net::HTTPOK.new("1.1", "200", "OK")
    authentication_response.instance_variable_set(:@read, true)
    authentication_response.body = { AccessToken: "token", User: { Id: "user-id" } }.to_json
    album_response = Net::HTTPOK.new("1.1", "200", "OK")
    album_response.instance_variable_set(:@read, true)
    album_response.body = { Id: "album-id", Type: "MusicAlbum" }.to_json
    tracks_response = Net::HTTPOK.new("1.1", "200", "OK")
    tracks_response.instance_variable_set(:@read, true)
    tracks_response.body = { Items: [ { Id: "second", Name: "Second", IndexNumber: 2 }, { Id: "first", Name: "First", IndexNumber: 1 } ], TotalRecordCount: 2 }.to_json
    http = FakeHttp.new([ authentication_response, album_response, tracks_response ])

    queue = Integrations::Jellyfin::Client.new(base_url: "https://example.com", username: "bruno", password: "secret", http: http).playback_queue("album-id")

    assert_equal [ "First", "Second" ], queue.items.pluck("Name")
    assert_equal "token", queue.access_token
  end

  test "builds a shuffled queue from an artist's tracks" do
    authentication_response = Net::HTTPOK.new("1.1", "200", "OK")
    authentication_response.instance_variable_set(:@read, true)
    authentication_response.body = { AccessToken: "token", User: { Id: "user-id" } }.to_json
    artist_response = Net::HTTPOK.new("1.1", "200", "OK")
    artist_response.instance_variable_set(:@read, true)
    artist_response.body = { Id: "artist-id", Type: "MusicArtist" }.to_json
    tracks_response = Net::HTTPOK.new("1.1", "200", "OK")
    tracks_response.instance_variable_set(:@read, true)
    tracks_response.body = { Items: [ { Id: "track-id", Name: "Random song" } ] }.to_json
    http = FakeHttp.new([ authentication_response, artist_response, tracks_response ])

    queue = Integrations::Jellyfin::Client.new(base_url: "https://example.com", username: "bruno", password: "secret", http: http).playback_queue("artist-id")

    parameters = URI.decode_www_form(URI.parse(http.last_request.path).query).to_h
    assert_equal [ "Random song" ], queue.items.pluck("Name")
    assert_equal "artist-id", parameters["ArtistIds"]
    assert_equal "Audio", parameters["IncludeItemTypes"]
    assert_equal "Random", parameters["SortBy"]
    assert_equal "20", parameters["Limit"]
  end
end
