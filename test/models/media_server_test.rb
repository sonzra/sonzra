require "test_helper"

class MediaServerTest < ActiveSupport::TestCase
  test "normalizes a trailing slash from the shared server address" do
    server = MediaServer.create!(name: "Home", provider: :jellyfin, base_url: "https://jellyfin.example.com/")

    assert_equal "https://jellyfin.example.com", server.base_url
  end

  test "does not allow the same provider and address to be configured twice" do
    MediaServer.create!(name: "Home", provider: :jellyfin, base_url: "https://jellyfin.example.com")
    duplicate = MediaServer.new(name: "Duplicate", provider: :jellyfin, base_url: "https://jellyfin.example.com")

    assert_not_predicate duplicate, :valid?
    assert_includes duplicate.errors[:base_url], "has already been taken"
  end
end
