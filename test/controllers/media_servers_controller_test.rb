require "test_helper"

class MediaServersControllerTest < ActionDispatch::IntegrationTest
  test "lets an administrator remove an unused server configuration" do
    media_server = MediaServer.create!(name: "Unused Plex", provider: :plex, base_url: "http://plex.example.com")

    get media_servers_url
    assert_response :success
    assert_select "h2", "Unused Plex"
    assert_select "form[action='#{media_server_path(media_server)}'] input[name='_method'][value='delete']"

    assert_difference("MediaServer.count", -1) { delete media_server_url(media_server) }
    assert_redirected_to media_servers_url
  end

  test "does not remove a server configuration that users still use" do
    media_server = MediaServer.create!(name: "In use", provider: :jellyfin, base_url: "http://jellyfin.example.com")
    ServerConnection.create!(media_server:, user: users(:one), username: "bruno", password: "secret")

    assert_no_difference("MediaServer.count") { delete media_server_url(media_server) }
    assert_redirected_to media_servers_url
  end
end
