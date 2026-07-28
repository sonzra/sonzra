require "test_helper"

class ServerConnections::FetchHomeContentTest < ActiveSupport::TestCase
  test "returns the library content from its client" do
    content = { user_name: "Bruno", recently_played: [], recently_added_albums: [], recently_added_artists: [], genres: [] }
    response = Integrations::Jellyfin::HomeContentResponseData.new(content: content, access_token: "token")
    client = Object.new
    client.define_singleton_method(:home_content) { response }

    result = ServerConnections::FetchHomeContent.new(server_connection, client: client).call

    assert_predicate result, :success?
    assert_equal content, result.content
    assert_equal "token", result.access_token
  end

  private

  def server_connection
    ServerConnection.new(name: "Home", provider: :jellyfin, base_url: "https://example.com", username: "bruno", password: "secret")
  end
end
