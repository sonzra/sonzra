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

  test "share_playlist issues POST to Playlists/{playlist_id}/Users/{user_id} with CanEdit param" do
    http = FakeHttp.new([ auth_response, build_ok_response({}) ])

    client = Integrations::Jellyfin::Client.new(
      base_url: "https://jellyfin.example.com",
      username: "user",
      password: "pw",
      http: http
    )

    assert client.share_playlist(playlist_id: "playlist-123", user_id: "user-target", can_edit: true)
    assert_equal "/Playlists/playlist-123/Users/user-target?CanEdit=true", http.last_request.path
    assert_equal "POST", http.last_request.method
  end

  test "share_playlist forwards can_edit: false parameter" do
    http = FakeHttp.new([ auth_response, build_no_content_response ])

    client = Integrations::Jellyfin::Client.new(
      base_url: "https://jellyfin.example.com",
      username: "user",
      password: "pw",
      http: http
    )

    assert client.share_playlist(playlist_id: "playlist-123", user_id: "user-target", can_edit: false)
    assert_equal "/Playlists/playlist-123/Users/user-target?CanEdit=false", http.last_request.path
    assert_equal "POST", http.last_request.method
  end

  test "unshare_playlist issues DELETE to Playlists/{playlist_id}/Users/{user_id}" do
    http = FakeHttp.new([ auth_response, build_no_content_response ])

    client = Integrations::Jellyfin::Client.new(
      base_url: "https://jellyfin.example.com",
      username: "user",
      password: "pw",
      http: http
    )

    assert client.unshare_playlist(playlist_id: "playlist-123", user_id: "user-target")
    assert_equal "/Playlists/playlist-123/Users/user-target", http.last_request.path
    assert_equal "DELETE", http.last_request.method
  end

  test "share_playlist raises error when server returns error response" do
    error_resp = Net::HTTPInternalServerError.new("1.1", "500", "Server Error")
    error_resp.instance_variable_set(:@read, true)
    http = FakeHttp.new([ auth_response, error_resp ])

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
