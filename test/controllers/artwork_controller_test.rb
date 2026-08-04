require "test_helper"

class ArtworkControllerTest < ActionDispatch::IntegrationTest
  class FakeClient
    def library_collection(*, **)
      Integrations::Jellyfin::LibraryCollectionResponseData.new(content: [], total: 0, access_token: "token")
    end

    def artwork(item_id:, tag:, access_token:)
      Integrations::Jellyfin::ArtworkResponseData.new(body: "image-data", content_type: "image/webp")
    end
  end

  setup do
    @server_connection = ServerConnection.create!(
      name: "Artwork server",
      provider: :jellyfin,
      base_url: "https://jellyfin.example.com",
      username: "bruno",
      password: "secret",
      user: users(:one)
    )
  end

  test "marks tagged artwork as immutable browser-cached content" do
    client_class = Integrations::Jellyfin::Client
    original_new = client_class.method(:new)
    client_class.define_singleton_method(:new) { |**_attributes| FakeClient.new }

    get library_albums_url
    assert_response :success

    get artwork_server_connection_url(@server_connection, "album-id", tag: "cover-tag")

    assert_response :success
    assert_equal "image/webp", response.media_type
    assert_equal "image-data", response.body
    assert_includes response.headers["Cache-Control"], "private"
    assert_includes response.headers["Cache-Control"], "immutable"
    assert_match(/max-age=\d+/, response.headers["Cache-Control"])
  ensure
    client_class&.define_singleton_method(:new, original_new) if original_new
  end
end
