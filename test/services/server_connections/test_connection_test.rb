require "test_helper"

class ServerConnections::TestConnectionTest < ActiveSupport::TestCase
  test "returns the authenticated user name when the connection succeeds" do
    client = Object.new
    client.define_singleton_method(:authenticate) { "Bruno" }

    result = ServerConnections::TestConnection.new(server_connection, client: client).call

    assert_predicate result, :success?
    assert_equal "Connected as Bruno.", result.message
  end

  test "returns a useful message for rejected credentials" do
    client = Object.new
    client.define_singleton_method(:authenticate) do
      raise Integrations::Jellyfin::Client::AuthenticationError
    end

    result = ServerConnections::TestConnection.new(server_connection, client: client).call

    assert_not_predicate result, :success?
    assert_equal "The saved server credentials were rejected.", result.message
  end

  test "forwards device_id to integration client when client is not injected" do
    fake_client = Object.new
    fake_client.define_singleton_method(:authenticate) { "Bruno" }

    original_for = Integrations::Client.method(:for)
    received_options = nil
    Integrations::Client.define_singleton_method(:for) do |_conn, **options|
      received_options = options
      fake_client
    end

    begin
      result = ServerConnections::TestConnection.new(server_connection, device_id: "test-device-id").call

      assert_predicate result, :success?
      assert_equal "test-device-id", received_options[:device_id]
    ensure
      Integrations::Client.define_singleton_method(:for, original_for)
    end
  end

  private

  def server_connection
    ServerConnection.new(
      name: "Home server",
      provider: :jellyfin,
      base_url: "https://jellyfin.example.com",
      username: "bruno",
      password: "secret"
    )
  end
end
