# frozen_string_literal: true

require "test_helper"

class ServerConnections::CollaborativePlaylists::SharePlaylistTest < ActiveSupport::TestCase
  class FakeClient
    attr_reader :shared_calls, :unshared_calls, :playlist_users_calls

    def initialize(supports_collab: true, playlist_users: [], fail_with: nil)
      @supports_collab = supports_collab
      @playlist_users = playlist_users
      @fail_with = fail_with
      @shared_calls = []
      @unshared_calls = []
      @playlist_users_calls = []
    end

    def supports?(capability)
      capability == Integrations::Capabilities::COLLABORATIVE_PLAYLISTS ? @supports_collab : true
    end

    def playlist_users(playlist_id)
      raise @fail_with if @fail_with

      @playlist_users_calls << playlist_id
      @playlist_users
    end

    def share_playlist(playlist_id:, user_id:, can_edit: true)
      raise @fail_with if @fail_with

      @shared_calls << { playlist_id: playlist_id, user_id: user_id, can_edit: can_edit }
      true
    end

    def unshare_playlist(playlist_id:, user_id:)
      raise @fail_with if @fail_with

      @unshared_calls << { playlist_id: playlist_id, user_id: user_id }
      true
    end
  end

  class FakeResolvingClient
    attr_reader :authenticated

    def initialize(resolved_id: nil)
      @resolved_id = resolved_id
      @authenticated = false
    end

    def authenticate
      @authenticated = true
      "user"
    end

    def resolved_user_id
      @authenticated ? @resolved_id : nil
    end
  end

  setup do
    @media_server = MediaServer.create!(name: "Home", provider: :jellyfin, base_url: "https://jellyfin.example.com")
    @user1 = users(:one)
    @user2 = User.create!(email_address: "collaborator@example.com", password: "password", password_confirmation: "password")
    @connection1 = ServerConnection.create!(user: @user1, media_server: @media_server, username: "user1", password: "pw1", remote_user_id: "remote-1")
    @connection2 = ServerConnection.create!(user: @user2, media_server: @media_server, username: "user2", password: "pw2", remote_user_id: "remote-2")
  end

  test "shares playlist with a fellow connection on the same media server" do
    fake_client = FakeClient.new
    service = ServerConnections::CollaborativePlaylists::SharePlaylist.new(
      @connection1, @connection2, playlist_id: "pl-42", client: fake_client
    )

    result = service.call

    assert result.success?
    assert_nil result.message
    assert_equal 1, fake_client.shared_calls.size
    assert_equal({ playlist_id: "pl-42", user_id: "remote-2", can_edit: true }, fake_client.shared_calls.first)
  end

  test "shares playlist with custom can_edit parameter" do
    fake_client = FakeClient.new
    service = ServerConnections::CollaborativePlaylists::SharePlaylist.new(
      @connection1, @connection2, playlist_id: "pl-42", can_edit: false, client: fake_client
    )

    result = service.call

    assert result.success?
    assert_equal false, fake_client.shared_calls.first[:can_edit]
  end

  test "fails when client provider does not support collaborative playlists" do
    fake_client = FakeClient.new(supports_collab: false)
    service = ServerConnections::CollaborativePlaylists::SharePlaylist.new(
      @connection1, @connection2, playlist_id: "pl-42", client: fake_client
    )

    result = service.call

    assert_not result.success?
    assert_equal "Provider does not support collaborative playlists", result.message
  end

  test "fails when target connection belongs to a different media server" do
    other_server = MediaServer.create!(name: "Other", provider: :jellyfin, base_url: "https://other.example.com")
    other_user = User.create!(email_address: "other@example.com", password: "password", password_confirmation: "password")
    other_connection = ServerConnection.create!(user: other_user, media_server: other_server, username: "other", password: "pw")

    fake_client = FakeClient.new
    service = ServerConnections::CollaborativePlaylists::SharePlaylist.new(
      @connection1, other_connection, playlist_id: "pl-42", client: fake_client
    )

    result = service.call

    assert_not result.success?
    assert_equal "Target connection is not on the same media server", result.message
  end

  test "resolves and caches remote user id when target connection lacks it" do
    @connection2.update_column(:remote_user_id, nil)

    target_client = FakeResolvingClient.new(resolved_id: "resolved-user-2")
    fake_client = FakeClient.new

    service = ServerConnections::CollaborativePlaylists::SharePlaylist.new(
      @connection1, @connection2, playlist_id: "pl-42", client: fake_client, target_client: target_client
    )

    result = service.call

    assert result.success?
    assert_equal "resolved-user-2", @connection2.reload.remote_user_id
    assert_equal "resolved-user-2", fake_client.shared_calls.first[:user_id]
  end

  test "fails when remote user id cannot be resolved" do
    @connection2.update_column(:remote_user_id, nil)

    target_client = FakeResolvingClient.new(resolved_id: nil)
    fake_client = FakeClient.new

    service = ServerConnections::CollaborativePlaylists::SharePlaylist.new(
      @connection1, @connection2, playlist_id: "pl-42", client: fake_client, target_client: target_client
    )

    result = service.call

    assert_not result.success?
    assert_equal "Unable to resolve remote user account", result.message
  end

  test "handles Integrations::Error from client gracefully" do
    fake_client = FakeClient.new(fail_with: Integrations::ConnectionError.new("Network timeout"))
    service = ServerConnections::CollaborativePlaylists::SharePlaylist.new(
      @connection1, @connection2, playlist_id: "pl-42", client: fake_client
    )

    result = service.call

    assert_not result.success?
    assert_equal "Network timeout", result.message
  end

  test "unshare playlist successfully calls client unshare_playlist" do
    fake_client = FakeClient.new
    service = ServerConnections::CollaborativePlaylists::UnsharePlaylist.new(
      @connection1, @connection2, playlist_id: "pl-42", client: fake_client
    )

    result = service.call

    assert result.success?
    assert_nil result.message
    assert_equal 1, fake_client.unshared_calls.size
    assert_equal({ playlist_id: "pl-42", user_id: "remote-2" }, fake_client.unshared_calls.first)
  end

  test "fetch playlist users successfully returns user list" do
    users_list = [ { "UserId" => "remote-1", "CanEdit" => true } ]
    fake_client = FakeClient.new(playlist_users: users_list)
    service = ServerConnections::CollaborativePlaylists::FetchPlaylistUsers.new(
      @connection1, playlist_id: "pl-42", client: fake_client
    )

    result = service.call

    assert result.success?
    assert_equal users_list, result.users
    assert_nil result.message
  end

  test "fetch playlist users fails when provider unsupported" do
    fake_client = FakeClient.new(supports_collab: false)
    service = ServerConnections::CollaborativePlaylists::FetchPlaylistUsers.new(
      @connection1, playlist_id: "pl-42", client: fake_client
    )

    result = service.call

    assert_not result.success?
    assert_equal "Provider does not support collaborative playlists", result.message
  end
end
