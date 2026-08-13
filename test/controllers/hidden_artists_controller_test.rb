require "test_helper"

class HiddenArtistsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @connection = ServerConnection.create!(name: "Library", provider: :jellyfin, base_url: "https://jellyfin.example.com", username: "bruno", password: "secret", user: users(:one))
  end

  test "hides and restores an artist for the current user connection" do
    post hidden_artists_url, params: { server_connection_id: @connection.id, artist_id: "artist-id", name: "Artist" }
    assert_equal [ "artist-id" ], users(:one).hidden_artists.pluck(:artist_id)

    delete hidden_artist_url(users(:one).hidden_artists.first)
    assert_empty users(:one).hidden_artists
  end
end
