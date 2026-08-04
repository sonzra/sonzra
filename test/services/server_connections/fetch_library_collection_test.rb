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

  test "supports music shelf collections" do
    response = Integrations::Jellyfin::LibraryCollectionResponseData.new(content: [ { "Name" => "Track" } ], total: 1, access_token: "token")
    client = Object.new
    requested_collection = nil
    client.define_singleton_method(:library_collection) { |collection, **| requested_collection = collection; response }

    result = ServerConnections::FetchLibraryCollection.new(server_connection, :recently_played, client: client).call

    assert_predicate result, :success?
    assert_equal :recently_played, requested_collection
    assert_equal [ { "Name" => "Track" } ], result.items
  end

  private

  def server_connection
    ServerConnection.new(name: "Home", provider: :jellyfin, base_url: "https://example.com", username: "bruno", password: "secret")
  end
end
