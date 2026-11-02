require "test_helper"

class HiddenGenresControllerTest < ActionDispatch::IntegrationTest
  setup do
    @connection = ServerConnection.create!(name: "Library", provider: :jellyfin, base_url: "https://jellyfin.example.com", username: "bruno", password: "secret", user: users(:one))
  end

  test "renders the hidden genres index page with empty state" do
    get hidden_genres_url
    assert_response :success
    assert_select "h1", "Hidden genres"
    assert_select "h2", "No hidden genres"
  end

  test "renders existing hidden genres with unhide buttons" do
    HiddenGenre.create!(user: users(:one), server_connection: @connection, name: "Holiday")

    get hidden_genres_url
    assert_response :success
    assert_select "h2", "Holiday"
    assert_select "button", "Unhide"
  end

  test "hides a genre for the specified connection via HTML" do
    post hidden_genres_url, params: { server_connection_id: @connection.id, name: "Ambient" }
    assert_redirected_to hidden_genres_url
    assert_equal [ "Ambient" ], users(:one).hidden_genres.pluck(:name)
  end

  test "hides a genre for the specified connection via JSON" do
    post hidden_genres_url, params: { server_connection_id: @connection.id, name: "Podcast" }, as: :json
    assert_response :created
    assert_equal [ "Podcast" ], users(:one).hidden_genres.pluck(:name)
  end

  test "restores a hidden genre via DELETE" do
    hidden = HiddenGenre.create!(user: users(:one), server_connection: @connection, name: "Holiday")

    delete hidden_genre_url(hidden)
    assert_redirected_to hidden_genres_url
    assert_empty users(:one).hidden_genres
  end
end
