require "test_helper"

class ServerConnections::FetchLibraryCollectionTest < ActiveSupport::TestCase
  test "returns a fetched library collection" do
    response = Integrations::LibraryCollectionResponseData.new(content: [ { "Name" => "Artist" } ], total: 1, access_token: "token")
    client = Object.new
    client.define_singleton_method(:library_collection) { |_, **| response }

    result = ServerConnections::FetchLibraryCollection.new(server_connection, :artists, client: client).call

    assert_predicate result, :success?
    assert_equal [ { "Name" => "Artist" } ], result.items
    assert_not result.has_more
  end

  test "calculates has_more based on total count and current page" do
    response = Integrations::LibraryCollectionResponseData.new(content: Array.new(60) { { "Name" => "Artist" } }, total: 120, access_token: "token")
    client = Object.new
    client.define_singleton_method(:library_collection) { |_, **| response }

    result = ServerConnections::FetchLibraryCollection.new(server_connection, :artists, page: 1, client: client).call

    assert result.has_more
  end

  test "passes letter parameter to client library collection" do
    response = Integrations::LibraryCollectionResponseData.new(content: [ { "Name" => "Beatles" } ], total: 1, access_token: "token")
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
    response = Integrations::LibraryCollectionResponseData.new(content: [ { "Name" => "Track" } ], total: 1, access_token: "token")
    client = Object.new
    requested_collection = nil
    client.define_singleton_method(:library_collection) { |collection, **| requested_collection = collection; response }

    result = ServerConnections::FetchLibraryCollection.new(server_connection, :recently_played, client: client).call

    assert_predicate result, :success?
    assert_equal :recently_played, requested_collection
    assert_equal [ { "Name" => "Track" } ], result.items
  end

  test "filters out albums and songs with hidden genres" do
    connection = ServerConnection.create!(name: "Home", provider: :jellyfin, base_url: "https://example.com", username: "bruno", password: "secret", user: users(:one))
    HiddenGenre.create!(user: users(:one), server_connection: connection, name: "Holiday")

    response = Integrations::LibraryCollectionResponseData.new(
      content: [
        { "Id" => "album-1", "Name" => "Xmas Album", "Genres" => [ "Holiday" ] },
        { "Id" => "album-2", "Name" => "Rock Album", "Genres" => [ "Rock" ] }
      ],
      total: 2,
      access_token: "token"
    )
    client = Object.new
    client.define_singleton_method(:library_collection) { |_, **| response }

    result = ServerConnections::FetchLibraryCollection.new(connection, :albums, user: users(:one), client:).call

    assert_equal [ "album-2" ], result.items.pluck("Id")
  end

  test "enriches playlists with collaboration status when collaborative capability is supported" do
    response = Integrations::LibraryCollectionResponseData.new(
      content: [
        { "Id" => "p-owned", "Name" => "My Private Mix" },
        { "Id" => "p-collab", "Name" => "Road Trip" },
        { "Id" => "p-shared", "Name" => "Friend Playlist" }
      ],
      total: 3,
      access_token: "token"
    )
    client = Object.new
    client.define_singleton_method(:library_collection) { |_, **| response }
    client.define_singleton_method(:supports?) { |cap| cap == Integrations::Capabilities::COLLABORATIVE_PLAYLISTS }
    client.define_singleton_method(:playlist_users) do |playlist_id|
      case playlist_id
      when "p-owned" then []
      when "p-collab" then [ { "UserId" => "other-user", "CanEdit" => true } ]
      when "p-shared" then raise Integrations::ConnectionError, "The server returned HTTP 403."
      end
    end

    result = ServerConnections::FetchLibraryCollection.new(server_connection, :playlists, client: client).call

    assert_predicate result, :success?
    items = result.items
    assert_equal :owned, items[0]["CollaborationStatus"]
    assert_equal true, items[0]["IsOwner"]
    assert_equal true, items[0]["CanDelete"]

    assert_equal :collaborative, items[1]["CollaborationStatus"]
    assert_equal true, items[1]["IsOwner"]
    assert_equal false, items[1]["CanDelete"]

    assert_equal :shared_with_me, items[2]["CollaborationStatus"]
    assert_equal false, items[2]["IsOwner"]
    assert_equal false, items[2]["CanDelete"]
  end

  private

  def server_connection
    ServerConnection.new(name: "Home", provider: :jellyfin, base_url: "https://example.com", username: "bruno", password: "secret")
  end
end
