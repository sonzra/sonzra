require "test_helper"

class HiddenGenres::FilterTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @connection = ServerConnection.create!(name: "Library", provider: :jellyfin, base_url: "https://jellyfin.example.com", username: "bruno", password: "secret", user: @user)
    HiddenGenre.create!(user: @user, server_connection: @connection, name: "Holiday")
    HiddenGenre.create!(user: @user, server_connection: @connection, name: "Ambient")
  end

  test "returns all items unchanged when user is nil or has no hidden genres" do
    items = [
      { "Id" => "track-1", "Genres" => [ "Holiday" ] },
      { "Id" => "track-2", "Genres" => [ "Rock" ] }
    ]

    assert_equal 2, HiddenGenres::Filter.new(nil, @connection).items(items).size
    assert_equal 2, HiddenGenres::Filter.new(users(:two), @connection).items(items).size
  end

  test "filters out tracks and albums where any genre matches hidden genres case-insensitively" do
    items = [
      { "Id" => "album-1", "Type" => "MusicAlbum", "Genres" => [ "holiday", "Pop" ] },
      { "Id" => "album-2", "Type" => "MusicAlbum", "Genres" => [ "Rock" ] },
      { "Id" => "album-3", "Type" => "MusicAlbum", "Genres" => [ "AMBIENT" ] }
    ]

    filtered = HiddenGenres::Filter.new(@user, @connection).items(items)
    assert_equal [ "album-2" ], filtered.pluck("Id")
  end

  test "filters out items using GenreItems array" do
    items = [
      { "Id" => "track-1", "GenreItems" => [ { "Name" => "Holiday", "Id" => "g1" } ] },
      { "Id" => "track-2", "GenreItems" => [ { "Name" => "Jazz", "Id" => "g2" } ] }
    ]

    filtered = HiddenGenres::Filter.new(@user, @connection).items(items)
    assert_equal [ "track-2" ], filtered.pluck("Id")
  end

  test "filters out genre cards and genre name strings" do
    genres = [
      { "Id" => "g1", "Name" => "Holiday", "Type" => "MusicGenre" },
      { "Id" => "g2", "Name" => "Classical", "Type" => "MusicGenre" }
    ]

    filtered = HiddenGenres::Filter.new(@user, @connection).items(genres)
    assert_equal [ "Classical" ], filtered.pluck("Name")

    raw_strings = [ "Holiday", "Rock", "ambient" ]
    assert_equal [ "Rock" ], HiddenGenres::Filter.new(@user, @connection).items(raw_strings)
  end

  test "handles items with missing or nil genre attributes gracefully" do
    items = [
      { "Id" => "track-clean" },
      { "Id" => "track-nil", "Genres" => nil },
      { "Id" => "track-empty", "Genres" => [] }
    ]

    filtered = HiddenGenres::Filter.new(@user, @connection).items(items)
    assert_equal 3, filtered.size
  end
end
