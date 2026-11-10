require "test_helper"

module Api
  module V1
    module Library
      class ArtistsControllerTest < ActionDispatch::IntegrationTest
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
          get api_v1_library_artists_url
          assert_response :unauthorized
          json = JSON.parse(response.body)
          assert_equal "Unauthorized", json["error"]
        end

        test "authenticates with Bearer token header" do
          sign_out
          api_token = @user.generate_token_for(:api_token)

          client = Object.new
          client.define_singleton_method(:library_collection) do |*, **|
            Integrations::LibraryCollectionResponseData.new(
              content: [ { "Id" => "artist-1", "Name" => "Radiohead", "Type" => "MusicArtist" } ],
              total: 1,
              access_token: "tok-123"
            )
          end

          original_for = Integrations::Client.method(:for)
          Integrations::Client.define_singleton_method(:for) { |*, **| client }

          get api_v1_library_artists_url, headers: { "Authorization" => "Bearer #{api_token}" }
          assert_response :success
          json = JSON.parse(response.body)
          assert_kind_of Array, json
          assert_equal 1, json.size
          assert_equal "artist-1", json.first["id"]
          assert_equal "Radiohead", json.first["name"]
        ensure
          Integrations::Client.define_singleton_method(:for, original_for)
        end

        test "authenticates with X-API-Token header" do
          sign_out
          api_token = @user.generate_token_for(:api_token)

          client = Object.new
          client.define_singleton_method(:library_collection) do |*, **|
            Integrations::LibraryCollectionResponseData.new(
              content: [],
              total: 0,
              access_token: "tok-123"
            )
          end

          original_for = Integrations::Client.method(:for)
          Integrations::Client.define_singleton_method(:for) { |*, **| client }

          get api_v1_library_artists_url, headers: { "X-API-Token" => api_token }
          assert_response :success
        ensure
          Integrations::Client.define_singleton_method(:for, original_for)
        end

        test "returns list of artists with expected fields" do
          client = Object.new
          client.define_singleton_method(:library_collection) do |*, **|
            Integrations::LibraryCollectionResponseData.new(
              content: [
                { "Id" => "art-1", "Name" => "Massive Attack", "Type" => "MusicArtist" },
                { "Id" => "art-2", "Name" => "Tricky", "Type" => "MusicArtist" }
              ],
              total: 2,
              access_token: "token"
            )
          end

          original_for = Integrations::Client.method(:for)
          Integrations::Client.define_singleton_method(:for) { |*, **| client }

          get api_v1_library_artists_url
          assert_response :success
          json = JSON.parse(response.body)
          assert_kind_of Array, json
          assert_equal 2, json.size

          first = json.first
          assert_equal "art-1", first["id"]
          assert_equal "Massive Attack", first["name"]
          assert_equal "/server_connections/#{@server_connection.id}/artwork/art-1", first["artwork_url"]
          assert_equal @server_connection.id, first["server_connection_id"]
        ensure
          Integrations::Client.define_singleton_method(:for, original_for)
        end

        test "forwards query parameters to collection fetcher" do
          received_options = nil
          client = Object.new
          client.define_singleton_method(:library_collection) do |_collection, **options|
            received_options = options
            Integrations::LibraryCollectionResponseData.new(content: [], total: 0, access_token: nil)
          end

          original_for = Integrations::Client.method(:for)
          Integrations::Client.define_singleton_method(:for) { |*, **| client }

          get api_v1_library_artists_url, params: { page: 2, q: "Beatles", letter: "B" }
          assert_response :success
          assert_equal 2, received_options[:page]
          assert_equal "Beatles", received_options[:query]
          assert_equal "B", received_options[:letter]
        ensure
          Integrations::Client.define_singleton_method(:for, original_for)
        end

        test "returns 422 if user has no server connection" do
          @server_connection.destroy!
          get api_v1_library_artists_url
          assert_response :unprocessable_entity
          json = JSON.parse(response.body)
          assert_equal "No server connection found", json["error"]
        end

        test "handles backend connection errors with 502 Bad Gateway" do
          client = Object.new
          client.define_singleton_method(:library_collection) do |*, **|
            raise Integrations::ConnectionError, "Server connection failed"
          end

          original_for = Integrations::Client.method(:for)
          Integrations::Client.define_singleton_method(:for) { |*, **| client }

          get api_v1_library_artists_url
          assert_response :bad_gateway
          json = JSON.parse(response.body)
          assert_equal "Server connection failed", json["error"]
        ensure
          Integrations::Client.define_singleton_method(:for, original_for)
        end
      end
    end
  end
end
