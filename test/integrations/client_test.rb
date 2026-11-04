require "test_helper"

class Integrations::ClientTest < ActiveSupport::TestCase
  test "instantiates Jellyfin client with forwarded device_id" do
    server = MediaServer.new(name: "Home", provider: :jellyfin, base_url: "https://example.com")
    connection = ServerConnection.new(user: users(:one), media_server: server, username: "bruno", password: "secret")

    client = Integrations::Client.for(connection, device_id: "sonzra-worker-99")
    assert_equal "sonzra-worker-99", client.instance_variable_get(:@device_id)
  end

  test "instantiates Plex client without raising argument errors" do
    server = MediaServer.new(name: "Home", provider: :plex, base_url: "https://plex.example.com")
    connection = ServerConnection.new(user: users(:one), media_server: server, access_token: "plex-token")

    ENV["PLEX_CLIENT_ID"] = "test-client-id"
    client = Integrations::Client.for(connection, device_id: "sonzra-worker-99")
    assert_instance_of Integrations::Plex::Client, client
  ensure
    ENV.delete("PLEX_CLIENT_ID")
  end
end
