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

  test "requires a complete HTTP or HTTPS server address" do
    connection = build_connection(base_url: "jellyfin.local")

    assert_not connection.valid?
    assert_includes connection.errors[:base_url], "must be a complete HTTP or HTTPS URL"
  end

  test "normalizes a trailing slash from the server address" do
    connection = create_connection(base_url: "https://jellyfin.example.com/")

    assert_equal "https://jellyfin.example.com", connection.base_url
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
      name: "Home server #{SecureRandom.uuid}",
      provider: :jellyfin,
      base_url: "https://jellyfin.example.com",
      username: "bruno",
      password: "secret"
    }
  end
end
