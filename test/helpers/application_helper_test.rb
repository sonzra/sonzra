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

  test "uses the premiere date and production year for a release year" do
    assert_equal "2024", release_year({ "PremiereDate" => "2024-06-01T00:00:00.0000000Z", "ProductionYear" => 2023 })
    assert_equal "1999", release_year({ "ProductionYear" => 1999 })
  end

  test "splits and de-duplicates semicolon-delimited music genres" do
    genres = [ { "Name" => "Ambient; Electronic" }, { "Name" => "Electronic; Jazz" }, { "Name" => "" } ]

    assert_equal [ "Ambient", "Electronic", "Jazz" ], music_genre_names(genres)
  end

  test "formats Jellyfin ticks as a track duration" do
    assert_equal "3:21", track_duration(2_010_000_000)
  end

  test "formats album runtime summary for short and multi-hour albums" do
    tracks_short = [
      { "RunTimeTicks" => 1_200_000_000 },
      { "RunTimeTicks" => 1_800_000_000 }
    ]
    assert_equal "5 min", album_runtime_summary(tracks_short)

    tracks_long = [
      { "RunTimeTicks" => 36_000_000_000 },
      { "RunTimeTicks" => 9_000_000_000 }
    ]
    assert_equal "1 hr 15 min", album_runtime_summary(tracks_long)

    assert_equal "0 min", album_runtime_summary([])
  end

  private

  def server_connection
    @server_connection ||= ServerConnection.create!(name: "Home", provider: :jellyfin, base_url: "https://example.com", username: "bruno", password: "secret", user: users(:one))
  end
end
