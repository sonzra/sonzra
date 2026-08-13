require "test_helper"

class Integrations::Plex::LyricsParserTest < ActiveSupport::TestCase
  test "supports multiple timestamps and plain lyric lines" do
    lines = Integrations::Plex::LyricsParser.call("[00:01.00][00:03.00]Repeat\nA plain line\n[ar:Artist]")

    assert_equal [
      { "Text" => "Repeat", "Start" => 10_000_000.0 },
      { "Text" => "Repeat", "Start" => 30_000_000.0 },
      { "Text" => "A plain line" }
    ], lines
  end
end
