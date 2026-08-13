require "test_helper"

class HiddenArtists::FilterTest < ActiveSupport::TestCase
  setup do
    @connection = ServerConnection.create!(name: "Library", provider: :jellyfin, base_url: "https://jellyfin.example.com", username: "bruno", password: "secret", user: users(:one))
    HiddenArtist.create!(user: users(:one), server_connection: @connection, artist_id: "artist-a", name: "Artist A")
  end

  test "removes artist cards and media belonging to hidden artists" do
    items = [
      { "Id" => "artist-a", "Name" => "Artist A", "Type" => "MusicArtist" },
      { "Id" => "album-a", "Type" => "MusicAlbum", "AlbumArtists" => [ { "Id" => "artist-a" } ] },
      { "Id" => "album-b", "Type" => "MusicAlbum", "AlbumArtists" => [ { "Id" => "artist-b" } ] }
    ]

    assert_equal [ "album-b" ], HiddenArtists::Filter.new(users(:one), @connection).items(items).pluck("Id")
  end

  test "removes hidden tracks from a visible compilation album" do
    tracks = [
      { "Id" => "track-a", "Type" => "Audio", "ArtistItems" => [ { "Id" => "artist-a" } ] },
      { "Id" => "track-b", "Type" => "Audio", "ArtistItems" => [ { "Id" => "artist-b" } ] }
    ]

    assert_equal [ "track-b" ], HiddenArtists::Filter.new(users(:one), @connection).items(tracks).pluck("Id")
  end
end
