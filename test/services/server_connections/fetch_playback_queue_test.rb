require "test_helper"

class ServerConnections::FetchPlaybackQueueTest < ActiveSupport::TestCase
  test "returns the tracks prepared by the integration" do
    response = Integrations::Jellyfin::PlaybackQueueResponseData.new(items: [ { "Name" => "First" } ], access_token: "token")
    client = Object.new
    client.define_singleton_method(:playback_queue) { |_| response }

    result = ServerConnections::FetchPlaybackQueue.new(server_connection, "album-id", client: client).call

    assert_predicate result, :success?
    assert_equal [ { "Name" => "First" } ], result.items
  end

  private

  def server_connection
    ServerConnection.new(name: "Home", provider: :jellyfin, base_url: "https://example.com", username: "bruno", password: "secret")
  end
end
