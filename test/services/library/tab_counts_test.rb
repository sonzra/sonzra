require "test_helper"

class Library::TabCountsTest < ActiveSupport::TestCase
  test "returns a total for every tab while sharing one integration client" do
    connection = ServerConnection.create!(
      media_server: MediaServer.create!(name: "Tab count server", provider: :jellyfin, base_url: "https://tab-counts.example.com"),
      username: "bruno",
      password: "secret",
      user: users(:one)
    )
    client = Object.new
    calls = []
    client.define_singleton_method(:library_collection) do |collection, **|
      calls << collection
      Integrations::Jellyfin::LibraryCollectionResponseData.new(content: [], total: collection.to_s.length, access_token: "token")
    end

    client_class = Integrations::Client
    original_for = client_class.method(:for)
    client_class.define_singleton_method(:for) { |_| client }

    counts = Library::TabCounts.new(connection, user: users(:one)).call

    assert_equal Library::TabCounts::COLLECTIONS, calls
    assert_equal 6, counts.fetch(:albums)
    assert_equal 6, counts.fetch(:genres)
  ensure
    Rails.cache.delete([ "library-tab-counts", connection.cache_key_with_version, users(:one).cache_key_with_version ]) if connection
    client_class.define_singleton_method(:for, original_for) if client_class && original_for
  end
end
