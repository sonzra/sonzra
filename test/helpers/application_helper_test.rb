require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "uses album artwork for a song without its own image" do
    path = library_artwork_path(server_connection, { "Id" => "song", "AlbumId" => "album", "AlbumPrimaryImageTag" => "tag" })

    assert_equal "/server_connections/#{server_connection.id}/artwork/album?tag=tag", path
  end

  test "uses the fallback cover when image metadata is unavailable" do
    path = library_artwork_path(server_connection, { "Id" => "album" })

    assert_nil path
  end

  test "uses the branded fallback artwork when image metadata is unavailable" do
    path = media_artwork_path(server_connection, { "Id" => "album" })

    assert_equal "/brand/sonzra-mark.svg", path
  end

  test "splits and de-duplicates semicolon-delimited music genres" do
    genres = [ { "Name" => "Ambient; Electronic" }, { "Name" => "Electronic; Jazz" }, { "Name" => "" } ]

    assert_equal [ "Ambient", "Electronic", "Jazz" ], music_genre_names(genres)
  end

  test "formats Jellyfin ticks as a track duration" do
    assert_equal "3:21", track_duration(2_010_000_000)
  end

  private

  def server_connection
    @server_connection ||= ServerConnection.create!(name: "Home", provider: :jellyfin, base_url: "https://example.com", username: "bruno", password: "secret", user: users(:one))
  end
end
