require "test_helper"

class ServerConnectionTest < ActiveSupport::TestCase
  test "encrypts credentials at rest" do
    connection = create_connection
    encrypted_username = ServerConnection.connection.select_value(
      "SELECT username FROM server_connections WHERE id = #{connection.id}"
    )
    encrypted_password = ServerConnection.connection.select_value(
      "SELECT password FROM server_connections WHERE id = #{connection.id}"
    )

    assert_equal "bruno", connection.reload.username
    assert_equal "secret", connection.password
    assert_not_includes encrypted_username, "bruno"
    assert_not_includes encrypted_password, "secret"
  end

  test "shares the media server while keeping credentials on each user connection" do
    server = MediaServer.create!(name: "Home", provider: :jellyfin, base_url: "https://jellyfin.example.com")
    first_connection = ServerConnection.create!(user: users(:one), media_server: server, username: "bruno", password: "secret")
    second_user = User.create!(email_address: "second@example.com", password: "password", password_confirmation: "password")
    second_connection = ServerConnection.create!(user: second_user, media_server: server, username: "second", password: "another-secret")

    assert_equal first_connection.media_server, second_connection.media_server
    assert_equal "bruno", first_connection.username
    assert_equal "second", second_connection.username
  end

  test "requires a complete HTTP or HTTPS server address" do
    connection = build_connection(media_server: MediaServer.new(name: "Home", provider: :jellyfin, base_url: "jellyfin.local"))

    assert_not connection.media_server.valid?
    assert_includes connection.media_server.errors[:base_url], "must be a complete HTTP or HTTPS URL"
  end

  test "normalizes a trailing slash from the server address" do
    connection = create_connection(media_server: MediaServer.new(name: "Home", provider: :jellyfin, base_url: "https://jellyfin.example.com/"))

    assert_equal "https://jellyfin.example.com", connection.base_url
  end

  test "includes an explicit remote user id override when building client options" do
    connection = create_connection

    assert_equal "user-id", connection.client_options(remote_user_id: "user-id")[:remote_user_id]
    assert_nil connection.client_options[:remote_user_id]
  end

  private

  def create_connection(**attributes)
    ServerConnection.create!(connection_attributes.merge(attributes))
  end

  def build_connection(**attributes)
    ServerConnection.new(connection_attributes.merge(attributes))
  end

  def connection_attributes
    {
      media_server: MediaServer.new(name: "Home server #{SecureRandom.uuid}", provider: :jellyfin, base_url: "https://jellyfin.example.com"),
      username: "bruno",
      password: "secret",
      user: users(:one)
    }
  end
end
