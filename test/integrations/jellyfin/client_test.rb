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

  test "fetches most-played songs and albums for the home screen" do
    authentication_response = Net::HTTPOK.new("1.1", "200", "OK")
    authentication_response.instance_variable_set(:@read, true)
    authentication_response.body = { AccessToken: "token", User: { Id: "user-id", Name: "Bruno" } }.to_json
    collection_responses = Array.new(8) do
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
      response.call(Items: []),
      response.call(Items: [ { Id: "podcast-series", Name: "Podcast series", ParentId: "podcast-library" }, { Id: "album-id", Name: "Music album", ParentId: "music-library" } ]),
      response.call(Items: []),
      response.call(Items: []),
      response.call(Items: [ { Id: "song-id", Name: "Played song", UserData: { PlayCount: 3 } } ]),
      response.call(Items: [ { Id: "podcast-series", Name: "Podcast series", ParentId: "podcast-library", UserData: { PlayCount: 4 } }, { Id: "album-id", Name: "Music album", ParentId: "music-library", UserData: { PlayCount: 2 } } ]),
      response.call(Items: [ { Id: "audiobook-id", Name: "Audio book", Type: "AudioBook" } ]),
      response.call(Items: [ { Id: "podcast-id", Name: "Podcast episode", Type: "Audio" } ])
    ]
    http = FakeHttp.new([ authentication_response, *responses ])

    content = Integrations::Jellyfin::Client.new(base_url: "https://example.com", username: "bruno", password: "secret", http: http).home_content.content

    assert_equal [ "Music album" ], content[:recently_added_albums].pluck("Name")
    assert_equal [ "Played song" ], content[:most_played_songs].pluck("Name")
    assert_equal [ "Music album" ], content[:most_played_albums].pluck("Name")
    assert_equal [ "Audio book" ], content[:recently_added_audiobooks].pluck("Name")
    assert_equal [ "Podcast episode" ], content[:recently_added_podcasts].pluck("Name")
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

  test "fetches podcast audio from the podcast library" do
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
    assert_equal "Audio", parameters["IncludeItemTypes"]
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
