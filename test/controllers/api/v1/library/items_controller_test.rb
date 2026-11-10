require "test_helper"

module Api
  module V1
    module Library
      class ItemsControllerTest < ActionDispatch::IntegrationTest
        setup do
          @user = users(:one)
          @server_connection = ServerConnection.create!(
            media_server: MediaServer.create!(name: "Home", provider: :jellyfin, base_url: "https://example.com"),
            username: "bruno",
            password: "secret",
            user: @user
          )
        end

        test "requires authentication" do
          sign_out
          get api_v1_library_item_url(id: "item-123")
          assert_response :unauthorized
          json = JSON.parse(response.body)
          assert_equal "Unauthorized", json["error"]
        end

        test "returns album details with tracklist, stream URLs, and artwork URLs" do
          details = {
            item: {
              "Id" => "alb-1",
              "Name" => "In Rainbows",
              "AlbumArtist" => "Radiohead",
              "ProductionYear" => 2007,
              "Type" => "MusicAlbum",
              "Overview" => "Seventh studio album"
            },
            album: {
              "Id" => "alb-1",
              "Name" => "In Rainbows",
              "AlbumArtist" => "Radiohead",
              "ProductionYear" => 2007,
              "Type" => "MusicAlbum",
              "Overview" => "Seventh studio album"
            },
            tracks: [
              {
                "Id" => "trk-1",
                "Name" => "15 Step",
                "AlbumArtist" => "Radiohead",
                "Album" => "In Rainbows",
                "IndexNumber" => 1,
                "ParentIndexNumber" => 1,
                "RunTimeTicks" => 2370000000 # 3:57 = 237 seconds
              },
              {
                "Id" => "trk-2",
                "Name" => "Bodysnatchers",
                "AlbumArtist" => "Radiohead",
                "Album" => "In Rainbows",
                "IndexNumber" => 2,
                "ParentIndexNumber" => 1,
                "RunTimeTicks" => 2420000000 # 4:02 = 242 seconds
              }
            ],
            other_albums: [],
            similar_albums: []
          }

          client = Object.new
          client.define_singleton_method(:library_item_details) do |_id|
            Integrations::LibraryItemDetailsResponseData.new(details: details, access_token: "tok")
          end

          original_for = Integrations::Client.method(:for)
          Integrations::Client.define_singleton_method(:for) { |*, **| client }

          get api_v1_library_item_url(id: "alb-1")
          assert_response :success
          json = JSON.parse(response.body)

          assert_equal "alb-1", json["id"]
          assert_equal "In Rainbows", json["name"]
          assert_equal "Radiohead", json["artist"]
          assert_equal "2007", json["year"]
          assert_equal "/server_connections/#{@server_connection.id}/artwork/alb-1", json["artwork_url"]
          assert_equal @server_connection.id, json["server_connection_id"]
          assert_equal "Seventh studio album", json["overview"]

          tracks = json["tracks"]
          assert_equal 2, tracks.size

          track1 = tracks.first
          assert_equal "trk-1", track1["id"]
          assert_equal "15 Step", track1["title"]
          assert_equal "Radiohead", track1["artist"]
          assert_equal "In Rainbows", track1["album"]
          assert_equal 1, track1["track_number"]
          assert_equal 237, track1["duration_seconds"]
          assert_equal "3:57", track1["duration"]
          assert_equal "/server_connections/#{@server_connection.id}/audio/trk-1", track1["stream_url"]
          assert_equal "/server_connections/#{@server_connection.id}/audio/trk-1", track1["audio_url"]
          assert_equal "/server_connections/#{@server_connection.id}/artwork/trk-1", track1["artwork_url"]
          assert_equal @server_connection.id, track1["server_connection_id"]
        ensure
          Integrations::Client.define_singleton_method(:for, original_for)
        end

        test "returns artist details with discography" do
          details = {
            item: {
              "Id" => "art-1",
              "Name" => "Radiohead",
              "Type" => "MusicArtist",
              "Overview" => "English rock band"
            },
            album: { "Id" => "art-1", "Name" => "Radiohead", "Type" => "MusicArtist" },
            tracks: [],
            other_albums: [
              {
                "Id" => "alb-1",
                "Name" => "The Bends",
                "AlbumArtist" => "Radiohead",
                "ProductionYear" => 1995
              },
              {
                "Id" => "alb-2",
                "Name" => "OK Computer",
                "AlbumArtist" => "Radiohead",
                "ProductionYear" => 1997
              }
            ],
            similar_albums: []
          }

          client = Object.new
          client.define_singleton_method(:library_item_details) do |_id|
            Integrations::LibraryItemDetailsResponseData.new(details: details, access_token: "tok")
          end

          original_for = Integrations::Client.method(:for)
          Integrations::Client.define_singleton_method(:for) { |*, **| client }

          get api_v1_library_item_url(id: "art-1")
          assert_response :success
          json = JSON.parse(response.body)

          assert_equal "art-1", json["id"]
          assert_equal "Radiohead", json["name"]
          assert_equal "MusicArtist", json["type"]
          assert_equal "/server_connections/#{@server_connection.id}/artwork/art-1", json["artwork_url"]
          assert_equal @server_connection.id, json["server_connection_id"]

          discography = json["discography"]
          assert_equal 2, discography.size
          assert_equal "alb-1", discography.first["id"]
          assert_equal "The Bends", discography.first["name"]
          assert_equal "/server_connections/#{@server_connection.id}/artwork/alb-1", discography.first["artwork_url"]
        ensure
          Integrations::Client.define_singleton_method(:for, original_for)
        end

        test "returns longform details for audiobook or podcast" do
          details = {
            kind: :audiobook,
            item: {
              "Id" => "ab-1",
              "Name" => "Neuromancer",
              "AlbumArtist" => "William Gibson",
              "Type" => "AudioBook",
              "RunTimeTicks" => 36000000000,
              "UserData" => { "PlaybackPositionTicks" => 18000000000 }
            },
            tracks: [],
            chapters: [
              { "Name" => "Chapter 1", "StartPositionTicks" => 0 }
            ]
          }

          client = Object.new
          client.define_singleton_method(:library_item_details) do |_id|
            Integrations::LibraryItemDetailsResponseData.new(details: details, access_token: "tok")
          end

          original_for = Integrations::Client.method(:for)
          Integrations::Client.define_singleton_method(:for) { |*, **| client }

          get api_v1_library_item_url(id: "ab-1")
          assert_response :success
          json = JSON.parse(response.body)

          assert_equal "ab-1", json["id"]
          assert_equal "Neuromancer", json["name"]
          assert_equal "audiobook", json["kind"]
          assert_equal "/server_connections/#{@server_connection.id}/audio/ab-1", json["stream_url"]
          assert_equal 1800.0, json["playback_position_seconds"]
        ensure
          Integrations::Client.define_singleton_method(:for, original_for)
        end

        test "handles backend connection errors with 502" do
          client = Object.new
          client.define_singleton_method(:library_item_details) do |_id|
            raise Integrations::ConnectionError, "Item not found on media server"
          end

          original_for = Integrations::Client.method(:for)
          Integrations::Client.define_singleton_method(:for) { |*, **| client }

          get api_v1_library_item_url(id: "missing")
          assert_response :bad_gateway
          json = JSON.parse(response.body)
          assert_equal "Item not found on media server", json["error"]
        ensure
          Integrations::Client.define_singleton_method(:for, original_for)
        end
      end
    end
  end
end
