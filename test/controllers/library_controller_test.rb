require "test_helper"

class LibraryControllerTest < ActionDispatch::IntegrationTest
  test "renders the audiobook library page" do
    get library_audiobooks_url

    assert_response :success
    assert_select "h1", "Connect a server to browse your library."
  end

  test "renders the podcast library page" do
    get library_podcasts_url

    assert_response :success
    assert_select "h1", "Connect a server to browse your library."
  end

  test "renders the genre directory" do
    get library_genres_url

    assert_response :success
    assert_select "h1", "Connect a server to browse your library."
  end
end
