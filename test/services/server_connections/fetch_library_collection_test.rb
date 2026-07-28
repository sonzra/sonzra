require "test_helper"

class ServerConnections::FetchLibraryCollectionTest < ActiveSupport::TestCase
  test "returns a fetched library collection" do
    response = Integrations::Jellyfin::LibraryCollectionResponseData.new(content: [ { "Name" => "Artist" } ], total: 1, access_token: "token")
    client = Object.new
    client.define_singleton_method(:library_collection) { |_, **| response }

    result = ServerConnections::FetchLibraryCollection.new(server_connection, :artists, client: client).call

    assert_predicate result, :success?
    assert_equal [ { "Name" => "Artist" } ], result.items
  end

  private

  def server_connection
    ServerConnection.new(name: "Home", provider: :jellyfin, base_url: "https://example.com", username: "bruno", password: "secret")
  end
end
