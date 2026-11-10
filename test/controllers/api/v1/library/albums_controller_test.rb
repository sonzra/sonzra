require "test_helper"

module Api
  module V1
    module Library
      class AlbumsControllerTest < ActionDispatch::IntegrationTest
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
          get api_v1_library_albums_url
          assert_response :unauthorized
          json = JSON.parse(response.body)
          assert_equal "Unauthorized", json["error"]
        end

        test "returns list of albums with expected fields" do
          client = Object.new
          client.define_singleton_method(:library_collection) do |*, **|
            Integrations::LibraryCollectionResponseData.new(
              content: [
                {
                  "Id" => "alb-1",
                  "Name" => "OK Computer",
                  "AlbumArtist" => "Radiohead",
                  "ProductionYear" => 1997,
                  "Type" => "MusicAlbum"
                },
                {
                  "Id" => "alb-2",
                  "Name" => "Dummy",
                  "AlbumArtist" => "Portishead",
                  "PremiereDate" => "1994-08-22T00:00:00Z",
                  "Type" => "MusicAlbum"
                }
              ],
              total: 2,
              access_token: "token"
            )
          end

          original_for = Integrations::Client.method(:for)
          Integrations::Client.define_singleton_method(:for) { |*, **| client }

          get api_v1_library_albums_url
          assert_response :success
          json = JSON.parse(response.body)
          assert_kind_of Array, json
          assert_equal 2, json.size

          first = json.first
          assert_equal "alb-1", first["id"]
          assert_equal "OK Computer", first["name"]
          assert_equal "Radiohead", first["artist"]
          assert_equal "1997", first["year"]
          assert_equal "/server_connections/#{@server_connection.id}/artwork/alb-1", first["artwork_url"]
          assert_equal @server_connection.id, first["server_connection_id"]

          second = json.second
          assert_equal "alb-2", second["id"]
          assert_equal "Dummy", second["name"]
          assert_equal "Portishead", second["artist"]
          assert_equal "1994", second["year"]
          assert_equal "/server_connections/#{@server_connection.id}/artwork/alb-2", second["artwork_url"]
        ensure
          Integrations::Client.define_singleton_method(:for, original_for)
        end

        test "forwards filtering parameters to collection fetcher" do
          received_options = nil
          client = Object.new
          client.define_singleton_method(:library_collection) do |_collection, **options|
            received_options = options
            Integrations::LibraryCollectionResponseData.new(content: [], total: 0, access_token: nil)
          end

          original_for = Integrations::Client.method(:for)
          Integrations::Client.define_singleton_method(:for) { |*, **| client }

          get api_v1_library_albums_url, params: { page: 3, q: "Computer", genre: "Rock", letter: "O" }
          assert_response :success
          assert_equal 3, received_options[:page]
          assert_equal "Computer", received_options[:query]
          assert_equal "Rock", received_options[:genre]
          assert_equal "O", received_options[:letter]
        ensure
          Integrations::Client.define_singleton_method(:for, original_for)
        end

        test "returns 422 if user has no server connection" do
          @server_connection.destroy!
          get api_v1_library_albums_url
          assert_response :unprocessable_entity
          json = JSON.parse(response.body)
          assert_equal "No server connection found", json["error"]
        end

        test "handles backend connection errors with 502 Bad Gateway" do
          client = Object.new
          client.define_singleton_method(:library_collection) do |*, **|
            raise Integrations::ConnectionError, "Connection timed out"
          end

          original_for = Integrations::Client.method(:for)
          Integrations::Client.define_singleton_method(:for) { |*, **| client }

          get api_v1_library_albums_url
          assert_response :bad_gateway
          json = JSON.parse(response.body)
          assert_equal "Connection timed out", json["error"]
        ensure
          Integrations::Client.define_singleton_method(:for, original_for)
        end
      end
    end
  end
end
