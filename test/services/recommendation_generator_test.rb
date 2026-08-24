require "test_helper"

class RecommendationGeneratorTest < ActiveSupport::TestCase
  setup do
    @connection = ServerConnection.create!(name: "Library", provider: :jellyfin, base_url: "https://jellyfin.example.com", username: "bruno", password: "secret", user: users(:one))
  end

  test "persists a stable 20-track Friday snapshot with artist and album limits" do
    items = 30.times.map do |index|
      { "Id" => "track-#{index}", "Name" => "Track #{index}", "AlbumArtist" => "Artist #{index / 3}", "AlbumId" => "album-#{index / 2}", "Album" => "Album #{index / 2}", "RunTimeTicks" => 1_800_000_000 }
    end
    client = Object.new
    client.define_singleton_method(:recommendation_tracks) { |_, _| items }

    collection = RecommendationGenerator.new(user: users(:one), strategy: "friday_rediscovery", period_date: Date.new(2026, 8, 14), client:).call

    assert_equal "Friday Rediscovery", collection.title
    assert_equal 20, collection.recommendation_tracks.count
    assert_operator collection.recommendation_tracks.group_by(&:artist).values.map(&:size).max, :<=, 3
    assert_equal collection, users(:one).recommendation_runs.last.recommendation_collection
  end

  test "excludes tracks shorter than one minute from mixes" do
    items = [
      { "Id" => "intro", "Name" => "Intro", "AlbumArtist" => "Artist", "AlbumId" => "album", "RunTimeTicks" => 590_000_000 },
      { "Id" => "song", "Name" => "Song", "AlbumArtist" => "Artist", "AlbumId" => "album", "RunTimeTicks" => 600_000_000 }
    ]
    client = Object.new
    client.define_singleton_method(:recommendation_tracks) { |_, _| items }

    collection = RecommendationGenerator.new(user: users(:one), strategy: "friday_rediscovery", period_date: Date.new(2026, 8, 14), client:).call

    assert_equal [ "song" ], collection.recommendation_tracks.pluck(:item_id)
  end

  test "only schedules Friday Rediscovery on Fridays" do
    assert RecommendationGenerator.scheduled?("friday_rediscovery", Date.new(2026, 8, 14))
    assert_not RecommendationGenerator.scheduled?("friday_rediscovery", Date.new(2026, 8, 13))
    assert RecommendationGenerator.scheduled?("best_of_genre", Date.new(2026, 8, 13))
    assert RecommendationGenerator.scheduled?("more_from_artist", Date.new(2026, 8, 12))
    assert_not RecommendationGenerator.scheduled?("more_from_artist", Date.new(2026, 8, 13))
    assert RecommendationGenerator.scheduled?("top_of_month", Date.new(2026, 8, 31))
    assert RecommendationGenerator.scheduled?("top_of_month", Date.new(2026, 8, 24))
    assert_not RecommendationGenerator.scheduled?("top_of_month", Date.new(2026, 8, 25))
  end

  test "builds Top of the Month from Sonzra playback starts in the current month" do
    [ [ "most-played", 3 ], [ "second", 2 ], [ "third", 1 ] ].each do |item_id, count|
      count.times { ListeningEvent.create!(user: users(:one), server_connection: @connection, item_id:, occurred_at: Time.zone.local(2026, 8, 10)) }
    end
    client = Object.new
    expected_item_ids = [ "most-played", "second", "third" ]
    client.define_singleton_method(:monthly_top_tracks) { |_| [] }
    client.define_singleton_method(:recommendation_tracks_by_ids) do |item_ids|
      item_ids.map.with_index do |item_id, index|
        { "Id" => item_id, "Name" => item_id, "AlbumArtist" => "Artist", "AlbumId" => "album-#{index}", "Album" => "Album", "RunTimeTicks" => 1_800_000_000 }
      end
    end

    collection = RecommendationGenerator.new(user: users(:one), strategy: "top_of_month", period_date: Date.new(2026, 8, 31), client:).call

    assert_equal "Top of August", collection.title
    assert_equal expected_item_ids, collection.recommendation_tracks.pluck(:item_id)
  end

  test "allows More from Artist to include up to 20 tracks from one artist" do
    items = 30.times.map do |index|
      { "Id" => "track-#{index}", "Name" => "Track #{index}", "AlbumArtist" => "Artist", "AlbumId" => "album-#{index / 2}", "Album" => "Album #{index / 2}", "RunTimeTicks" => 1_800_000_000 }
    end
    client = Object.new
    client.define_singleton_method(:recommendation_tracks) { |_, _| items }

    collection = RecommendationGenerator.new(user: users(:one), strategy: "more_from_artist", period_date: Date.new(2026, 8, 12), client:).call

    assert_equal "More from Artist", collection.title
    assert_equal 20, collection.recommendation_tracks.count
    assert_operator collection.recommendation_tracks.group_by(&:album_id).values.map(&:size).max, :<=, 2
  end

  test "creates separate snapshots when the user switches servers" do
    plex_connection = ServerConnection.create!(name: "Plex", provider: :plex, base_url: "https://plex.example.com", username: "bruno", access_token: "token", user: users(:one))
    items = [ { "Id" => "track", "Name" => "Track", "AlbumArtist" => "Artist", "AlbumId" => "album", "Album" => "Album", "RunTimeTicks" => 1_800_000_000 } ]
    jellyfin_client = Object.new
    jellyfin_client.define_singleton_method(:recommendation_tracks) { |_, _| items }
    plex_client = Object.new
    plex_client.define_singleton_method(:recommendation_tracks) { |_, _| items }

    first = RecommendationGenerator.new(user: users(:one), strategy: "best_of_genre", period_date: Date.new(2026, 8, 13), client: jellyfin_client).call
    users(:one).update!(preferred_server_connection: plex_connection)
    second = RecommendationGenerator.new(user: users(:one), strategy: "best_of_genre", period_date: Date.new(2026, 8, 13), client: plex_client).call

    assert_not_equal first.id, second.id
    assert_equal [ @connection.id, plex_connection.id ].sort, users(:one).recommendation_collections.where(strategy: "best_of_genre", period_date: Date.new(2026, 8, 13)).pluck(:server_connection_id).sort
  end

  test "ensure_all generates missing collections for scheduled strategies on period_date" do
    items = [ { "Id" => "track", "Name" => "Track", "AlbumArtist" => "Artist", "AlbumId" => "album", "Album" => "Album", "RunTimeTicks" => 1_800_000_000 } ]
    client = Object.new
    client.define_singleton_method(:recommendation_tracks) { |_, _| items }
    client.define_singleton_method(:monthly_top_tracks) { |_| items }

    RecommendationGenerator.ensure_all(user: users(:one), connection: @connection, period_date: Date.new(2026, 8, 14), client:)

    strategies = users(:one).recommendation_collections.where(server_connection: @connection).pluck(:strategy)
    assert_includes strategies, "friday_rediscovery"
    assert_includes strategies, "best_of_genre"
  end
end
