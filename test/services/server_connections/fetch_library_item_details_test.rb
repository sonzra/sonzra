require "test_helper"

class ServerConnections::FetchLibraryItemDetailsTest < ActiveSupport::TestCase
  test "returns details and a temporary access token" do
    details = { item: { "Name" => "Album" }, album: {}, tracks: [], other_albums: [], similar_albums: [] }
    response = Integrations::Jellyfin::LibraryItemDetailsResponseData.new(details: details, access_token: "token")
    client = Object.new
    client.define_singleton_method(:library_item_details) { |_| response }

    result = ServerConnections::FetchLibraryItemDetails.new(server_connection, "item", client: client).call

    assert_predicate result, :success?
    assert_equal details, result.details
    assert_equal "token", result.access_token
  end

  test "forwards access_token and device_id to Integrations::Client.for" do
    connection = server_connection
    received_options = nil
    fake_client = Object.new
    fake_client.define_singleton_method(:library_item_details) do |_|
      Integrations::Jellyfin::LibraryItemDetailsResponseData.new(
        details: { item: { "Name" => "Album" }, album: {}, tracks: [], other_albums: [], similar_albums: [] },
        access_token: "new-token"
      )
    end

    original_for = Integrations::Client.method(:for)
    Integrations::Client.define_singleton_method(:for) do |_conn, **opts|
      received_options = opts
      fake_client
    end

    begin
      result = ServerConnections::FetchLibraryItemDetails.new(
        connection, "item-1",
        access_token: "provided-token",
        device_id: "device-123"
      ).call

      assert_predicate result, :success?
      assert_equal "provided-token", received_options[:access_token]
      assert_equal "device-123", received_options[:device_id]
      assert_equal "new-token", result.access_token
    ensure
      Integrations::Client.define_singleton_method(:for, original_for)
    end
  end

  private

  def server_connection
    ServerConnection.new(name: "Home", provider: :jellyfin, base_url: "https://example.com", username: "bruno", password: "secret")
  end
end
