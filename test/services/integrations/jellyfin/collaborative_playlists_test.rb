require "test_helper"

class Integrations::Jellyfin::CollaborativePlaylistsTest < ActiveSupport::TestCase
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

  def build_ok_response(body_hash)
    response = Net::HTTPOK.new("1.1", "200", "OK")
    response.instance_variable_set(:@read, true)
    response.body = body_hash.to_json
    response
  end

  def build_no_content_response
    response = Net::HTTPNoContent.new("1.1", "204", "No Content")
    response.instance_variable_set(:@read, true)
    response
  end

  def auth_response
    build_ok_response(AccessToken: "test-token", User: { Id: "user-1", Name: "TestUser" })
  end

  test "playlist_users fetches users list when API returns Users key" do
    users_data = [
      { "UserId" => "user-2", "CanEdit" => true },
      { "UserId" => "user-3", "CanEdit" => false }
    ]
    playlist_users_resp = build_ok_response("Users" => users_data)
    http = FakeHttp.new([ auth_response, playlist_users_resp ])

    client = Integrations::Jellyfin::Client.new(
      base_url: "https://jellyfin.example.com",
      username: "user",
      password: "pw",
      http: http
    )

    result = client.playlist_users("playlist-123")
    assert_equal users_data, result
    assert_equal "/Playlists/playlist-123/Users", URI.parse(http.last_request.path).path
    assert_equal "GET", http.last_request.method
  end

  test "playlist_users fetches users list when API returns an array directly" do
    users_data = [
      { "UserId" => "user-2", "CanEdit" => true }
    ]
    resp = Net::HTTPOK.new("1.1", "200", "OK")
    resp.instance_variable_set(:@read, true)
    resp.body = users_data.to_json

    http = FakeHttp.new([ auth_response, resp ])

    client = Integrations::Jellyfin::Client.new(
      base_url: "https://jellyfin.example.com",
      username: "user",
      password: "pw",
      http: http
    )

    result = client.playlist_users("playlist-123")
    assert_equal users_data, result
  end

  test "share_playlist issues POST to Playlists/{playlist_id}/Users/{user_id} and synchronizes playlist ACL" do
    http = FakeHttp.new([
      auth_response,
      build_ok_response("Users" => []),
      build_no_content_response,
      build_no_content_response
    ])

    client = Integrations::Jellyfin::Client.new(
      base_url: "https://jellyfin.example.com",
      username: "user",
      password: "pw",
      http: http
    )

    assert client.share_playlist(playlist_id: "playlist-123", user_id: "user-target", can_edit: true)

    # Playlist ACL update request
    acl_req = http.requests[2]
    assert_equal "/Playlists/playlist-123", acl_req.path
    assert_equal "POST", acl_req.method
    assert_equal "application/json", acl_req["Content-Type"]
    acl_body = JSON.parse(acl_req.body)
    assert_equal false, acl_body["IsPublic"]
    assert_equal [ { "UserId" => "user-target", "CanEdit" => true } ], acl_body["Users"]

    # User endpoint request
    user_req = http.requests[3]
    assert_equal "/Playlists/playlist-123/Users/user-target", user_req.path
    assert_equal "POST", user_req.method
    assert_equal "application/json", user_req["Content-Type"]
    assert_equal({ "CanEdit" => true }, JSON.parse(user_req.body))
  end

  test "share_playlist forwards can_edit: false parameter in JSON body" do
    http = FakeHttp.new([
      auth_response,
      build_ok_response("Users" => []),
      build_no_content_response,
      build_no_content_response
    ])

    client = Integrations::Jellyfin::Client.new(
      base_url: "https://jellyfin.example.com",
      username: "user",
      password: "pw",
      http: http
    )

    assert client.share_playlist(playlist_id: "playlist-123", user_id: "user-target", can_edit: false)

    acl_req = http.requests[2]
    acl_body = JSON.parse(acl_req.body)
    assert_equal [ { "UserId" => "user-target", "CanEdit" => false } ], acl_body["Users"]

    user_req = http.requests[3]
    assert_equal "/Playlists/playlist-123/Users/user-target", user_req.path
    assert_equal "POST", user_req.method
    assert_equal({ "CanEdit" => false }, JSON.parse(user_req.body))
  end

  test "unshare_playlist issues DELETE and updates playlist ACL with remaining users" do
    http = FakeHttp.new([
      auth_response,
      build_ok_response("Users" => [
        { "UserId" => "user-target", "CanEdit" => true },
        { "UserId" => "user-other", "CanEdit" => true }
      ]),
      build_no_content_response,
      build_no_content_response
    ])

    client = Integrations::Jellyfin::Client.new(
      base_url: "https://jellyfin.example.com",
      username: "user",
      password: "pw",
      http: http
    )

    assert client.unshare_playlist(playlist_id: "playlist-123", user_id: "user-target")

    # Check ACL update request
    acl_req = http.requests[2]
    assert_equal "/Playlists/playlist-123", acl_req.path
    assert_equal "POST", acl_req.method
    acl_body = JSON.parse(acl_req.body)
    assert_equal false, acl_body["IsPublic"]
    assert_equal [ { "UserId" => "user-other", "CanEdit" => true } ], acl_body["Users"]

    # Check DELETE request
    delete_req = http.requests[3]
    assert_equal "/Playlists/playlist-123/Users/user-target", delete_req.path
    assert_equal "DELETE", delete_req.method
  end

  test "share_playlist raises error when server returns error response" do
    error_resp = Net::HTTPInternalServerError.new("1.1", "500", "Server Error")
    error_resp.instance_variable_set(:@read, true)
    http = FakeHttp.new([ auth_response, build_ok_response("Users" => []), error_resp ])

    client = Integrations::Jellyfin::Client.new(
      base_url: "https://jellyfin.example.com",
      username: "user",
      password: "pw",
      http: http
    )

    assert_raises(Integrations::ConnectionError) do
      client.share_playlist(playlist_id: "playlist-123", user_id: "user-target")
    end
  end
end
