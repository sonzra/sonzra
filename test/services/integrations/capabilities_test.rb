require "test_helper"

class Integrations::CapabilitiesTest < ActiveSupport::TestCase
  test "jellyfin client supports letter filtering capability" do
    client = Integrations::Jellyfin::Client.new(base_url: "https://jellyfin.example.com")
    assert client.supports?(Integrations::Capabilities::LETTER_FILTERING)
  end

  test "plex client does not support letter filtering capability" do
    previous_value = ENV["PLEX_CLIENT_ID"]
    ENV["PLEX_CLIENT_ID"] = "test-client-id"
    begin
      client = Integrations::Plex::Client.new(base_url: "https://plex.example.com")
      assert_not client.supports?(Integrations::Capabilities::LETTER_FILTERING)
    ensure
      ENV["PLEX_CLIENT_ID"] = previous_value if previous_value
    end
  end
end
