require "test_helper"

class ServerConnections::FetchLibraryCollectionTest < ActiveSupport::TestCase
  test "returns a fetched library collection" do
    response = Integrations::Jellyfin::LibraryCollectionResponseData.new(content: [ { "Name" => "Artist" } ], total: 1, access_token: "token")
    client = Object.new
    client.define_singleton_method(:library_collection) { |_, **| response }

    result = ServerConnections::FetchLibraryCollection.new(server_connection, :artists, client: client).call

    assert_predicate result, :success?
    assert_equal [ { "Name" => "Artist" } ], result.items
    assert_not result.has_more
  end

  test "calculates has_more based on total count and current page" do
    response = Integrations::Jellyfin::LibraryCollectionResponseData.new(content: Array.new(60) { { "Name" => "Artist" } }, total: 120, access_token: "token")
    client = Object.new
    client.define_singleton_method(:library_collection) { |_, **| response }

    result = ServerConnections::FetchLibraryCollection.new(server_connection, :artists, page: 1, client: client).call

    assert result.has_more
  end

  test "passes letter parameter to client library collection" do
    response = Integrations::Jellyfin::LibraryCollectionResponseData.new(content: [ { "Name" => "Beatles" } ], total: 1, access_token: "token")
    client = Object.new
    received_letter = nil
    client.define_singleton_method(:library_collection) { |_, **kwargs| received_letter = kwargs[:letter]; response }

    ServerConnections::FetchLibraryCollection.new(server_connection, :artists, letter: "B", client: client).call

    assert_equal "B", received_letter
  end

  test "delegates supports? check to provider client" do
    client = Object.new
    client.define_singleton_method(:supports?) { |cap| cap == :letter_filtering }

    service = ServerConnections::FetchLibraryCollection.new(server_connection, :artists, client: client)

    assert service.supports?(:letter_filtering)
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
