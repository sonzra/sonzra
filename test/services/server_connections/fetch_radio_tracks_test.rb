require "test_helper"

class ServerConnections::FetchRadioTracksTest < ActiveSupport::TestCase
  test "uses the selected server provider" do
    client = Object.new
    client.define_singleton_method(:instant_mix) do |item_id, limit:|
      @limit = limit
      Integrations::Jellyfin::PlaybackQueueResponseData.new(items: [ { "Id" => item_id } ], access_token: "token")
    end
    server_connection = ServerConnection.new(name: "Home", provider: :plex, base_url: "https://example.com", username: "bruno", access_token: "token")

    result = ServerConnections::FetchRadioTracks.new(server_connection, "track-id", client:).call

    assert result.success?
    assert_equal [ "track-id" ], result.items.pluck("Id")
    assert_equal 12, client.instance_variable_get(:@limit)
  end
end
