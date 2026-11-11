# frozen_string_literal: true

require "test_helper"

class CollaborativePlaylistsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @collaborator_user = users(:two)
    @media_server = MediaServer.create!(name: "Shared Jellyfin", provider: :jellyfin, base_url: "https://jellyfin.example.com")
    @server_connection = ServerConnection.create!(
      media_server: @media_server,
      username: "owner",
      password: "password",
      remote_user_id: "remote-owner-id",
      user: @user
    )
    @collaborator_connection = ServerConnection.create!(
      media_server: @media_server,
      username: "collab",
      password: "password",
      remote_user_id: "remote-collab-id",
      user: @collaborator_user
    )
  end

  test "index returns 403 when collaborative capability is unsupported" do
    sign_in_as @user
    client = Object.new
    client.define_singleton_method(:supports?) { |_| false }

    with_jellyfin_client(client) do
      get playlist_collaborators_server_connection_url(@server_connection, playlist_id: "playlist-1"), as: :json
    end

    assert_response :forbidden
    assert_equal "Collaborative playlists are not supported by this server", JSON.parse(response.body)["error"]
  end

  test "index returns fellow connections and collaborator status" do
    sign_in_as @user
    client = Object.new
    client.define_singleton_method(:supports?) { |cap| cap == Integrations::Capabilities::COLLABORATIVE_PLAYLISTS }
    client.define_singleton_method(:playlist_users) do |playlist_id|
      [ { "UserId" => "remote-collab-id", "CanEdit" => true } ] if playlist_id == "playlist-1"
    end

    with_jellyfin_client(client) do
      get playlist_collaborators_server_connection_url(@server_connection, playlist_id: "playlist-1"), as: :json
    end

    assert_response :ok
    payload = JSON.parse(response.body)
    assert_equal 1, payload["fellow_connections"].size
    connection_data = payload["fellow_connections"].first
    assert_equal @collaborator_connection.id, connection_data["id"]
    assert_equal @collaborator_user.email_address, connection_data["email"]
    assert_equal true, connection_data["is_collaborator"]
  end

  test "create shares playlist and delivers notification to target user" do
    sign_in_as @user
    client = Object.new
    client.define_singleton_method(:supports?) { |cap| cap == Integrations::Capabilities::COLLABORATIVE_PLAYLISTS }
    client.define_singleton_method(:share_playlist) { |playlist_id:, user_id:, can_edit: true| true }

    assert_difference -> { @collaborator_user.notifications.count }, 1 do
      with_jellyfin_client(client) do
        post share_playlist_server_connection_url(@server_connection, playlist_id: "playlist-1"),
             params: { target_connection_id: @collaborator_connection.id, playlist_name: "Summer Vibes" },
             as: :json
      end
    end

    assert_response :ok
    assert_equal true, JSON.parse(response.body)["success"]
    notification = @collaborator_user.notifications.last
    assert_equal "Playlist Shared", notification.title
    assert_match "Summer Vibes", notification.message
    assert_equal @user, notification.actor_user
  end

  test "destroy unshares playlist from target user" do
    sign_in_as @user
    client = Object.new
    client.define_singleton_method(:supports?) { |cap| cap == Integrations::Capabilities::COLLABORATIVE_PLAYLISTS }
    client.define_singleton_method(:unshare_playlist) { |playlist_id:, user_id:| true }

    with_jellyfin_client(client) do
      delete unshare_playlist_server_connection_url(@server_connection, playlist_id: "playlist-1", target_connection_id: @collaborator_connection.id),
             as: :json
    end

    assert_response :ok
    assert_equal true, JSON.parse(response.body)["success"]
  end

  private

  def sign_in_as(user)
    post session_url, params: { email_address: user.email_address, password: "password" }
  end

  def with_jellyfin_client(client)
    client_class = Integrations::Jellyfin::Client
    client_class.singleton_class.alias_method :new_before_collab_test, :new
    client_class.define_singleton_method(:new) { |**| client }
    yield
  ensure
    client_class.singleton_class.alias_method :new, :new_before_collab_test
    client_class.singleton_class.remove_method :new_before_collab_test
  end
end
