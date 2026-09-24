require "test_helper"

class RecommendationCollectionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @connection = ServerConnection.create!(name: "Library", provider: :jellyfin, base_url: "https://jellyfin.example.com", username: "bruno", password: "secret", user: users(:one))
    @collection = RecommendationCollection.create!(user: users(:one), server_connection: @connection, strategy: "best_of_genre", period_date: Date.current, title: "Best of ambient", subtitle: "A daily mix", generated_at: Time.current)
    @collection.recommendation_tracks.create!(item_id: "track-1", position: 1, title: "Track", artist: "Artist", artwork_item_id: "track-1")
  end

  test "lists saved mixes and returns their playback snapshot" do
    get recommendation_collections_url
    assert_response :success
    assert_select "h1", "Mixes"

    get recommendation_collection_url(@collection), headers: { "Accept" => "application/json" }
    payload = JSON.parse(response.body)
    assert_equal "track-1", payload.dig("items", 0, "item_id")
    assert_equal true, payload.dig("items", 0, "radio_eligible")

    get recommendation_collection_url(@collection)
    assert_response :success
    assert_select ".detail-hero h1", "Best of ambient"
    assert_select ".track-list.track-list--mixed", 1
    assert_select ".track-list strong[data-artist='Artist']", "Track"

    post events_recommendation_collection_url(@collection), params: { event_type: "started" }
    assert_response :created
    assert_equal "started", @collection.recommendation_collection_events.last.event_type
  end

  test "uses the standalone redesign layout for every saved mix" do
    users(:one).update!(ui_variant: "redesign")
    older_mix = RecommendationCollection.create!(user: users(:one), server_connection: @connection, strategy: "best_of_genre", period_date: Date.yesterday, title: "Yesterday's ambient", subtitle: "A previous session", generated_at: 1.day.ago)
    older_mix.recommendation_tracks.create!(item_id: "track-2", position: 1, title: "Older track", artist: "Artist", artwork_item_id: "track-2")

    get recommendation_collections_url

    assert_response :success
    assert_select ".redesign-library-heading h1", "Mixes"
    assert_select ".redesign-topbar__link", "Mixes"
    assert_select ".redesign-topbar__link[href='#{offline_downloads_path}']", "Downloads"
    assert_select ".redesign-bottom-nav a[href='#{offline_downloads_path}']", 0
    assert_select ".redesign-mix-card-grid .redesign-mix-card", 2
    assert_select ".redesign-mix-card time", /Created /
    assert_select ".redesign-mix-card", text: /Yesterday's ambient/

    get recommendation_collection_url(@collection)

    assert_response :success
    assert_select "header.redesign-topbar .redesign-brand", 1
    assert_select "header.redesign-media-topbar", 0
    assert_select "a.redesign-detail-back[href='#{recommendation_collections_path}'][data-controller='history-back']", "Back"
    assert_select ".redesign-discovery-detail .detail-hero h1", "Best of ambient"
    assert_select ".redesign-detail-actions .redesign-detail-action--play", "Play"
    assert_select ".redesign-detail-actions .redesign-detail-action--queue", "Add to queue"
    assert_select ".redesign-detail-tracks__heading", 1
    assert_select ".redesign-detail-tracks .listen-card__play", 1
    assert_select ".redesign-detail-tracks .track-list__queue", 1
    assert_select ".redesign-detail-tracks .detail-track__more", 1
    assert_select ".redesign-detail-tracks .detail-track__menu-panel button", 1
  end

  test "does not expose a hidden artist from a previously generated mix" do
    HiddenArtist.create!(user: users(:one), server_connection: @connection, artist_id: "artist-1", name: "Artist")

    get recommendation_collection_url(@collection), headers: { "Accept" => "application/json" }

    assert_equal [], JSON.parse(response.body).fetch("items")
  end
end
