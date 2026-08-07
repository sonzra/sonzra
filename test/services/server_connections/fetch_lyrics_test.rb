require "test_helper"

class ServerConnections::FetchLyricsTest < ActiveSupport::TestCase
  test "normalizes timed lyrics into browser seconds" do
    response = Integrations::Jellyfin::LyricsResponseData.new(
      lines: [ { "Text" => " First line ", "Start" => 25_000_000 }, { "Text" => "Second line", "Start" => 45_000_000 } ],
      access_token: "token",
      available: true
    )
    client = Object.new
    client.define_singleton_method(:lyrics) { |_| response }

    result = ServerConnections::FetchLyrics.new(server_connection, "track-id", client: client).call

    assert_predicate result, :success?
    assert result.available
    assert result.synchronized
    assert_equal [ { text: "First line", start: 2.5 }, { text: "Second line", start: 4.5 } ], result.lines
  end

  test "does not expose a single URL-like lyric line" do
    response = Integrations::Jellyfin::LyricsResponseData.new(
      lines: [ { "Text" => "b3n4.multiply.com collections" } ],
      access_token: "token",
      available: true
    )
    client = Object.new
    client.define_singleton_method(:lyrics) { |_| response }

    result = ServerConnections::FetchLyrics.new(server_connection, "track-id", client: client).call

    assert_predicate result, :success?
    assert_not result.available
    assert_empty result.lines
  end

  test "preserves grouped synchronized lyric text under its original timestamp" do
    response = Integrations::Jellyfin::LyricsResponseData.new(
      lines: [
        { "Text" => "First visual line\nSecond visual line", "Start" => 10_000_000 },
        { "Text" => "Third visual line", "Start" => 30_000_000 }
      ],
      access_token: "token",
      available: true
    )
    client = Object.new
    client.define_singleton_method(:lyrics) { |_| response }

    result = ServerConnections::FetchLyrics.new(server_connection, "track-id", client: client).call

    assert_equal [
      { text: "First visual line\nSecond visual line", start: 1.0 },
      { text: "Third visual line", start: 3.0 }
    ], result.lines
  end

  private

  def server_connection
    ServerConnection.new(name: "Home", provider: :jellyfin, base_url: "https://example.com", username: "bruno", password: "secret")
  end
end
