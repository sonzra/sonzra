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
    assert_select "h1", "Your mixes"

    get recommendation_collection_url(@collection), headers: { "Accept" => "application/json" }
    payload = JSON.parse(response.body)
    assert_equal "track-1", payload.dig("items", 0, "item_id")
    assert_equal true, payload.dig("items", 0, "radio_eligible")

    get recommendation_collection_url(@collection)
    assert_response :success
    assert_select ".detail-hero h1", "Best of ambient"
    assert_select ".track-list", 1

    post events_recommendation_collection_url(@collection), params: { event_type: "started" }
    assert_response :created
    assert_equal "started", @collection.recommendation_collection_events.last.event_type
  end
end
