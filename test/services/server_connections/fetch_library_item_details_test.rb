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

  private

  def server_connection
    ServerConnection.new(name: "Home", provider: :jellyfin, base_url: "https://example.com", username: "bruno", password: "secret")
  end
end
