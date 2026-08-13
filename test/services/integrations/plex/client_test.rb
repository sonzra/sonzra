require "test_helper"

class Integrations::Plex::ClientTest < ActiveSupport::TestCase
  class FakeHttp
    attr_reader :requests

    def initialize(responses)
      @responses = Array(responses)
      @requests = []
    end

    def start(...)
      yield self
    end

    def request(request)
      @requests << request
      @responses.shift
    end
  end

  def response(body)
    Net::HTTPOK.new("1.1", "200", "OK").tap do |http_response|
      http_response.instance_variable_set(:@read, true)
      http_response.body = body.to_json
    end
  end

  def created_response(location: nil)
    Net::HTTPCreated.new("1.1", "201", "Created").tap do |http_response|
      http_response.instance_variable_set(:@read, true)
      http_response.body = ""
      http_response["Location"] = location if location
    end
  end

  def plain_response(body)
    Net::HTTPOK.new("1.1", "200", "OK").tap do |http_response|
      http_response.instance_variable_set(:@read, true)
      http_response.body = body
    end
  end

  test "requires a client identifier only when a Plex client is created" do
    previous_value = ENV.delete("PLEX_CLIENT_ID")

    error = assert_raises(Integrations::Plex::Client::ConnectionError) { Integrations::Plex::Client.new(base_url: "http://plex.example.test") }
    assert_equal "PLEX_CLIENT_ID must be configured before adding a Plex connection.", error.message
  ensure
    ENV["PLEX_CLIENT_ID"] = previous_value if previous_value
  end

  test "uses the configured client identifier for Plex PIN approval" do
    previous_value = ENV["PLEX_CLIENT_ID"]
    ENV["PLEX_CLIENT_ID"] = "sonzra-installation-id"
    http = FakeHttp.new([
      response(id: 123, code: "ABCD"),
      response(authToken: "plex-token"),
      response(MediaContainer: { myPlexUsername: "Bruno" })
    ])
    client = Integrations::Plex::Client.new(base_url: "http://plex.example.test", http:)

    pin = client.initiate_pin(forward_url: "http://sonzra.example.test/server_connections/quick_connect")

    assert_equal "123", pin.fetch("id")
    assert_equal "ABCD", pin.fetch("code")
    assert_includes pin.fetch("url"), "clientID=sonzra-installation-id"
    assert_equal "plex-token", client.pin_status(pin_id: pin.fetch("id"), code: pin.fetch("code"))
    assert_equal "Bruno", client.authenticated_account_name(access_token: "plex-token")
    assert_equal "/api/v2/pins", http.requests.first.path
    assert_equal "strong=true", http.requests.first.body
    assert_equal "application/x-www-form-urlencoded", http.requests.first["Content-Type"]
    assert_equal "/", http.requests.last.path
    assert_equal "sonzra-installation-id", http.requests.last["X-Plex-Client-Identifier"]
    assert_equal "plex-token", http.requests.last["X-Plex-Token"]
  ensure
    ENV["PLEX_CLIENT_ID"] = previous_value if previous_value
  end

  test "creates a playlist with its initial track and accepts an empty created response" do
    previous_value = ENV["PLEX_CLIENT_ID"]
    ENV["PLEX_CLIENT_ID"] = "sonzra-installation-id"
    http = FakeHttp.new([
      response(MediaContainer: { machineIdentifier: "server-id" }),
      created_response(location: "/playlists/42")
    ])

    playlist_id = Integrations::Plex::Client.new(base_url: "http://plex.example.test", access_token: "plex-token", http:).create_playlist("Road trip", item_ids: [ "11" ])

    assert_equal "42", playlist_id
    assert_equal "/playlists?type=audio&title=Road+trip&smart=0&uri=server%3A%2F%2Fserver-id%2Fcom.plexapp.plugins.library%2Flibrary%2Fmetadata%2F11", http.requests.last.path
  ensure
    ENV["PLEX_CLIENT_ID"] = previous_value if previous_value
  end

  test "reports Plex playback through its timeline and scrobbles completed tracks" do
    previous_value = ENV["PLEX_CLIENT_ID"]
    ENV["PLEX_CLIENT_ID"] = "sonzra-installation-id"
    http = FakeHttp.new([ response({}), response({}) ])
    client = Integrations::Plex::Client.new(base_url: "http://plex.example.test", access_token: "plex-token", http:)

    client.report_playback(event: "stopped", item_id: "17", position_ticks: 180_000_000, duration_ticks: 200_000_000, paused: true)

    timeline = URI.decode_www_form(http.requests.first.uri.query).to_h
    assert_equal "/:/timeline", http.requests.first.path.split("?").first
    assert_equal({ "ratingKey" => "17", "key" => "/library/metadata/17", "state" => "stopped", "time" => "18000", "duration" => "20000", "type" => "music", "identifier" => "com.plexapp.plugins.library" }, timeline)
    assert_equal "/:/scrobble?key=17&identifier=com.plexapp.plugins.library", http.requests.last.path
  ensure
    ENV["PLEX_CLIENT_ID"] = previous_value if previous_value
  end

  test "clears Plex playback history when resetting a resume position" do
    previous_value = ENV["PLEX_CLIENT_ID"]
    ENV["PLEX_CLIENT_ID"] = "sonzra-installation-id"
    http = FakeHttp.new(response({}))

    Integrations::Plex::Client.new(base_url: "http://plex.example.test", access_token: "plex-token", http:).update_playback_position(item_id: "17", position_ticks: 0)

    assert_equal "/:/unscrobble?key=17&identifier=com.plexapp.plugins.library", http.requests.first.path
  ensure
    ENV["PLEX_CLIENT_ID"] = previous_value if previous_value
  end

  test "uses Plex user ratings for favourites" do
    previous_value = ENV["PLEX_CLIENT_ID"]
    ENV["PLEX_CLIENT_ID"] = "sonzra-installation-id"
    http = FakeHttp.new([ response({}), response({}) ])
    client = Integrations::Plex::Client.new(base_url: "http://plex.example.test", access_token: "plex-token", http:)

    client.update_favorite(item_id: "17", favorite: true)
    client.update_favorite(item_id: "17", favorite: false)

    assert_equal "/:/rate?key=17&identifier=com.plexapp.plugins.library&rating=10", http.requests.first.path
    assert_equal "/:/rate?key=17&identifier=com.plexapp.plugins.library&rating=0", http.requests.last.path
  ensure
    ENV["PLEX_CLIENT_ID"] = previous_value if previous_value
  end

  test "uses Plex sonic similarity for track radio" do
    previous_value = ENV["PLEX_CLIENT_ID"]
    ENV["PLEX_CLIENT_ID"] = "sonzra-installation-id"
    seed = { ratingKey: 17, type: "track", title: "Seed", parentTitle: "Album", parentRatingKey: 12, grandparentTitle: "Seed artist", grandparentRatingKey: 7, duration: 180_000 }
    track = seed.merge(ratingKey: 18, title: "Similar song", grandparentTitle: "Similar artist", grandparentRatingKey: 8)
    http = FakeHttp.new([
      response(MediaContainer: { Metadata: [ seed.merge(Genre: [ { tag: "Rock" } ], librarySectionID: 1) ] }),
      response(MediaContainer: { Metadata: [ track ] })
    ])

    result = Integrations::Plex::Client.new(base_url: "http://plex.example.test", access_token: "plex-token", http:).instant_mix("17", limit: 8)

    assert_equal [ "Similar song" ], result.items.pluck("Name")
    assert_equal "/library/metadata/17", http.requests.first.path
    assert_equal "/library/metadata/17/nearest?limit=8", http.requests.last.path
  ensure
    ENV["PLEX_CLIENT_ID"] = previous_value if previous_value
  end

  test "uses named Audiobooks and Podcasts libraries as dedicated long-form collections" do
    previous_value = ENV["PLEX_CLIENT_ID"]
    ENV["PLEX_CLIENT_ID"] = "sonzra-installation-id"
    sections = {
      MediaContainer: {
        Directory: [
          { key: "1", type: "artist", title: "Music" },
          { key: "2", type: "artist", title: "aUdIoBoOkS" },
          { key: "3", type: "artist", title: "PODCASTS" }
        ]
      }
    }
    audiobook = { ratingKey: 17, type: "track", title: "The book", librarySectionID: 2, duration: 180_000 }
    podcast = { ratingKey: 18, type: "track", title: "The episode", librarySectionID: 3, duration: 60_000 }
    http = FakeHttp.new([ response(sections), response(MediaContainer: { Metadata: [ audiobook ], totalSize: 1 }), response(MediaContainer: { Metadata: [ podcast ], totalSize: 1 }) ])
    client = Integrations::Plex::Client.new(base_url: "http://plex.example.test", access_token: "plex-token", http:)

    audiobooks = client.library_collection(:audiobooks, page: 1, query: nil)
    podcasts = client.library_collection(:podcasts, page: 1, query: nil)

    assert_equal "AudioBook", audiobooks.content.first["Type"]
    assert_equal "Audio", podcasts.content.first["Type"]
    assert_equal "/library/sections/2/all?type=10&sort=titleSort&X-Plex-Container-Start=0&X-Plex-Container-Size=48", http.requests[1].path
    assert_equal "/library/sections/3/all?type=10&sort=titleSort&X-Plex-Container-Start=0&X-Plex-Container-Size=48", http.requests[2].path
  ensure
    ENV["PLEX_CLIENT_ID"] = previous_value if previous_value
  end

  test "returns a Plex long-form item with its resume position" do
    previous_value = ENV["PLEX_CLIENT_ID"]
    ENV["PLEX_CLIENT_ID"] = "sonzra-installation-id"
    episode = { ratingKey: 17, type: "track", title: "The episode", librarySectionID: 3, librarySectionTitle: "Podcasts", duration: 60_000, viewOffset: 12_500 }
    http = FakeHttp.new(response(MediaContainer: { Metadata: [ episode ] }))

    result = Integrations::Plex::Client.new(base_url: "http://plex.example.test", access_token: "plex-token", http:).library_item_details("17")

    assert_equal :podcast, result.details[:kind]
    assert_equal 125_000_000, result.details[:item].dig("UserData", "PlaybackPositionTicks")
    assert_empty result.details[:tracks]
  ensure
    ENV["PLEX_CLIENT_ID"] = previous_value if previous_value
  end

  test "loads timed lyrics from a Plex lyric stream" do
    previous_value = ENV["PLEX_CLIENT_ID"]
    ENV["PLEX_CLIENT_ID"] = "sonzra-installation-id"
    track = { ratingKey: 17, Media: [ { Part: [ { Stream: [ { streamType: 4, key: "/library/streams/99" } ] } ] } ] }
    http = FakeHttp.new([ response(MediaContainer: { Metadata: [ track ] }), plain_response("[00:01.50]First line\n[00:03.00]Second line") ])

    result = Integrations::Plex::Client.new(base_url: "http://plex.example.test", access_token: "plex-token", http:).lyrics("17")

    assert result.available
    assert_equal [ { "Text" => "First line", "Start" => 15_000_000.0 }, { "Text" => "Second line", "Start" => 30_000_000.0 } ], result.lines
    assert_equal "/library/streams/99", http.requests.last.path
  ensure
    ENV["PLEX_CLIENT_ID"] = previous_value if previous_value
  end

  test "normalizes Plex lyric JSON spans instead of displaying the raw response" do
    previous_value = ENV["PLEX_CLIENT_ID"]
    ENV["PLEX_CLIENT_ID"] = "sonzra-installation-id"
    track = { ratingKey: 17, Media: [ { Part: [ { Stream: [ { streamType: 4, key: "/library/streams/99" } ] } ] } ] }
    lyrics = { MediaContainer: { Lyrics: [ { timed: true, Lyrics: [ { startOffset: 18_330, endOffset: 21_910, Span: [ { text: "I'm sorry for needing" } ] } ] } ] } }
    http = FakeHttp.new([ response(MediaContainer: { Metadata: [ track ] }), plain_response(lyrics.to_json) ])

    result = Integrations::Plex::Client.new(base_url: "http://plex.example.test", access_token: "plex-token", http:).lyrics("17")

    assert_equal [ { "Text" => "I'm sorry for needing", "Start" => 183_300_000.0 } ], result.lines
  ensure
    ENV["PLEX_CLIENT_ID"] = previous_value if previous_value
  end

  test "finds Plex lyric lines when the response omits the nested lyrics wrapper" do
    previous_value = ENV["PLEX_CLIENT_ID"]
    ENV["PLEX_CLIENT_ID"] = "sonzra-installation-id"
    track = { ratingKey: 17, Media: [ { Part: [ { Stream: [ { streamType: 4, key: "/library/streams/99" } ] } ] } ] }
    lyrics = { MediaContainer: { Lyrics: [ { timed: true, entries: [ { startOffset: 18_330, Span: [ { text: "First line" } ] } ] } ] } }
    http = FakeHttp.new([ response(MediaContainer: { Metadata: [ track ] }), plain_response(lyrics.to_json) ])

    result = Integrations::Plex::Client.new(base_url: "http://plex.example.test", access_token: "plex-token", http:).lyrics("17")

    assert_equal [ { "Text" => "First line", "Start" => 183_300_000.0 } ], result.lines
  ensure
    ENV["PLEX_CLIENT_ID"] = previous_value if previous_value
  end

  test "builds Plex recommendation candidates from music-library metadata" do
    previous_value = ENV["PLEX_CLIENT_ID"]
    ENV["PLEX_CLIENT_ID"] = "sonzra-installation-id"
    section = { key: "1", type: "artist", title: "Music" }
    unheard = { ratingKey: 18, type: "track", title: "Rediscovery", parentTitle: "Album", parentRatingKey: 12, grandparentTitle: "Artist", grandparentRatingKey: 8, duration: 180_000 }
    http = FakeHttp.new([
      response(MediaContainer: { Directory: [ section ] }),
      response(MediaContainer: { Metadata: [ unheard ] })
    ])

    tracks = Integrations::Plex::Client.new(base_url: "http://plex.example.test", access_token: "plex-token", http:).recommendation_tracks("friday_rediscovery", Date.new(2026, 8, 14))

    assert_equal [ "Rediscovery" ], tracks.pluck("Name")
    assert_equal "/library/sections/1/all?type=10&sort=random&X-Plex-Container-Size=200", http.requests.last.path
  ensure
    ENV["PLEX_CLIENT_ID"] = previous_value if previous_value
  end

  test "falls back to same-genre Plex tracks when sonic analysis is unavailable" do
    previous_value = ENV["PLEX_CLIENT_ID"]
    ENV["PLEX_CLIENT_ID"] = "sonzra-installation-id"
    seed = { ratingKey: 17, type: "track", title: "Seed", parentTitle: "Album", parentRatingKey: 12, grandparentTitle: "Artist", grandparentRatingKey: 7, duration: 180_000, Genre: [ { tag: "Rock" } ], librarySectionID: 1 }
    recommendation = seed.merge(ratingKey: 18, title: "Another rock song", grandparentRatingKey: 8, grandparentTitle: "Another artist")
    unavailable = Net::HTTPNotFound.new("1.1", "404", "Not Found").tap { |response| response.instance_variable_set(:@read, true); response.body = "" }
    http = FakeHttp.new([
      response(MediaContainer: { Metadata: [ seed ] }),
      unavailable,
      response(MediaContainer: { Metadata: [ recommendation ] })
    ])

    result = Integrations::Plex::Client.new(base_url: "http://plex.example.test", access_token: "plex-token", http:).instant_mix("17", limit: 8)

    assert_equal [ "Another rock song" ], result.items.pluck("Name")
    assert_equal "/library/sections/1/all?type=10&sort=random&genre=Rock&X-Plex-Container-Size=32", http.requests.last.path
  ensure
    ENV["PLEX_CLIENT_ID"] = previous_value if previous_value
  end

  test "falls back to diverse library tracks when no sonic analysis or genre is available" do
    previous_value = ENV["PLEX_CLIENT_ID"]
    ENV["PLEX_CLIENT_ID"] = "sonzra-installation-id"
    seed = { ratingKey: 17, type: "track", title: "Seed", parentTitle: "Album", parentRatingKey: 12, grandparentTitle: "Artist", grandparentRatingKey: 7, duration: 180_000, librarySectionID: 1 }
    recommendation = seed.merge(ratingKey: 18, title: "Another song", grandparentRatingKey: 8, grandparentTitle: "Another artist")
    unavailable = Net::HTTPNotFound.new("1.1", "404", "Not Found").tap { |response| response.instance_variable_set(:@read, true); response.body = "" }
    http = FakeHttp.new([
      response(MediaContainer: { Metadata: [ seed ] }),
      unavailable,
      response(MediaContainer: { Metadata: [ recommendation ] })
    ])

    result = Integrations::Plex::Client.new(base_url: "http://plex.example.test", access_token: "plex-token", http:).instant_mix("17", limit: 8)

    assert_equal [ "Another song" ], result.items.pluck("Name")
    assert_equal "/library/sections/1/all?type=10&sort=random&X-Plex-Container-Size=32", http.requests.last.path
  ensure
    ENV["PLEX_CLIENT_ID"] = previous_value if previous_value
  end

  test "uses the Plex Media Server root when given a Plex Web address" do
    previous_value = ENV["PLEX_CLIENT_ID"]
    ENV["PLEX_CLIENT_ID"] = "sonzra-installation-id"
    http = FakeHttp.new(response(MediaContainer: { friendlyName: "Music server" }))

    assert_equal "Music server", Integrations::Plex::Client.new(base_url: "http://plex.example.test:32400/web/", access_token: "plex-token", http:).authenticate
    assert_equal "/", http.requests.first.path
  ensure
    ENV["PLEX_CLIENT_ID"] = previous_value if previous_value
  end

  test "normalizes a Plex music library for the shared home dashboard" do
    previous_value = ENV["PLEX_CLIENT_ID"]
    ENV["PLEX_CLIENT_ID"] = "sonzra-installation-id"
    music_section = { key: "1", type: "artist", title: "Music" }
    track = { ratingKey: 101, type: "track", title: "Song", parentTitle: "Album", parentRatingKey: 12, grandparentTitle: "Artist", grandparentRatingKey: 7, duration: 180_000, thumb: "/library/metadata/12/thumb" }
    album = { ratingKey: 12, type: "album", title: "Album", parentTitle: "Artist", parentRatingKey: 7, thumb: "/library/metadata/12/thumb", year: 2024 }
    artist = { ratingKey: 7, type: "artist", title: "Artist", thumb: "/library/metadata/7/thumb" }
    http = FakeHttp.new([
      response(MediaContainer: { Directory: [ music_section ] }),
      response(MediaContainer: { myPlexUsername: "Bruno" }),
      response(MediaContainer: { Metadata: [ track ] }),
      response(MediaContainer: { Metadata: [ album ] }),
      response(MediaContainer: { Metadata: [ artist ] }),
      response(MediaContainer: { Directory: [ { key: "rock", title: "Rock" } ] }),
      response(MediaContainer: { Metadata: [ track ] }),
      response(MediaContainer: { Metadata: [ album ] })
    ])

    content = Integrations::Plex::Client.new(base_url: "http://plex.example.test", access_token: "plex-token", http:).home_content.content

    assert_equal "Bruno", content[:user_name]
    assert_equal "Song", content[:recently_played].first["Name"]
    assert_equal "Audio", content[:recently_played].first["Type"]
    assert_equal 1_800_000_000, content[:recently_played].first["RunTimeTicks"]
    assert_equal "Artist", content[:recently_added_albums].first["AlbumArtist"]
    assert_equal [ "Rock" ], content[:genres].pluck("Name")
    assert_equal "plex", content[:recently_added_artists].first.dig("ImageTags", "Primary")
    assert_equal "plex", content[:recently_played].first["AlbumPrimaryImageTag"]
    assert_empty content[:recently_played].first["ImageTags"]
  ensure
    ENV["PLEX_CLIENT_ID"] = previous_value if previous_value
  end
end
