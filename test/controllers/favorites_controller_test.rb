require "test_helper"

class FavoritesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @server_connection = ServerConnection.create!(
      media_server: MediaServer.create!(name: "Home server", provider: :plex, base_url: "https://plex.example.com"),
      username: "bruno",
      access_token: "token",
      user: users(:one)
    )
  end

  test "updates a favourite through the selected server provider" do
    client = Object.new
    updated = nil
    client.define_singleton_method(:update_favorite) { |**attributes| updated = attributes }
    client_factory = Integrations::Client.method(:for)
    Integrations::Client.define_singleton_method(:for) { |*_arguments| client }

    patch favorite_server_connection_url(@server_connection, "track-1"), params: { favorite: true }, as: :json

    assert_response :success
    assert_equal({ item_id: "track-1", favorite: true }, updated)
    assert_equal({ "favorite" => true }, JSON.parse(response.body))
  ensure
    Integrations::Client.define_singleton_method(:for, client_factory)
  end
end
