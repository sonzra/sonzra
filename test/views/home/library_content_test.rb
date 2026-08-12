require "test_helper"

class HomeLibraryContentTest < ActionView::TestCase
  test "prioritizes listening shelves and renders a balanced genre grid" do
    @server_connection = ServerConnection.create!(name: "Home", provider: :jellyfin, base_url: "https://example.com", username: "bruno", password: "secret", user: users(:one))
    item = { "Id" => "item-id", "Name" => "An item", "Type" => "MusicAlbum" }

    render partial: "home/library_content", locals: {
      content: {
        user_name: "Bruno",
        genres: %w[Ambient Jazz Rock Pop Classical Blues Electronic Folk Funk Hip-hop].map { |name| { "Name" => name } },
        recently_played: [ item ],
        most_played_songs: [ item.merge("Type" => "Audio") ],
        recently_added_albums: [ item ],
        continue_podcasts: [ item.merge("Type" => "Audio") ],
        continue_audiobooks: [ item.merge("Type" => "AudioBook") ],
        most_played_albums: [],
        recently_added_audiobooks: [],
        recently_added_podcasts: [],
        recently_added_artists: []
      }
    }

    assert_select ".genre-explorer__grid .genre-tile", 9
    assert_select ".genre-explorer__grid .genre-tile:last-child.genre-tile--all", "Browse all genres"
    assert_select ".genre-explorer__all-link", 0
    assert_equal [ "Recently played", "Most played songs", "Recently added albums", "Continue podcasts", "Continue audiobooks" ], css_select(".listen-section h2").map(&:text)
    assert_select "a[href='#{library_recently_played_path}']", "See all"
    assert_select "a[href='#{library_most_played_songs_path}']", "See all"
    assert_select "a[href='#{library_recently_added_albums_path}']", "See all"
  end
end
