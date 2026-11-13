require "test_helper"

class TrackSharesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @sender = users(:one)
    @recipient = users(:two)
    @valid_params = {
      recipient_id: @recipient.id,
      title: "Heroes",
      artist: "David Bowie",
      album: "Heroes",
      item_id: "track-789",
      artwork_item_id: "art-789",
      note: "One of my favorites!"
    }
  end

  test "creates track share and returns 201 Created with JSON format" do
    assert_difference "Notification.count", 1 do
      post track_shares_path, params: { track_share: @valid_params }, as: :json
    end

    assert_response :created
    json = response.parsed_body
    assert json["success"]
    assert_equal "Heroes", json.dig("notification", "title")
    assert_equal @recipient.id, json.dig("notification", "recipient_id")
    assert_equal @sender.id, json.dig("notification", "sender_id")
  end

  test "accepts flat params without top-level wrapper" do
    assert_difference "Notification.count", 1 do
      post track_shares_path, params: @valid_params, as: :json
    end

    assert_response :created
    json = response.parsed_body
    assert json["success"]
    assert_equal "Heroes", json.dig("notification", "title")
  end

  test "redirects with notice when submitting HTML form" do
    assert_difference "Notification.count", 1 do
      post track_shares_path, params: { track_share: @valid_params }
    end

    assert_response :redirect
    assert_redirected_to root_path
    assert_equal "Track shared successfully.", flash[:notice]
  end

  test "fails when recipient is not found" do
    assert_no_difference "Notification.count" do
      post track_shares_path, params: { track_share: @valid_params.merge(recipient_id: 999_999) }, as: :json
    end

    assert_response :unprocessable_entity
    json = response.parsed_body
    assert_not json["success"]
    assert_equal "Recipient not found", json["error"]
  end

  test "fails when sender tries to share with themselves" do
    assert_no_difference "Notification.count" do
      post track_shares_path, params: { track_share: @valid_params.merge(recipient_id: @sender.id) }, as: :json
    end

    assert_response :unprocessable_entity
    json = response.parsed_body
    assert_not json["success"]
    assert_equal "Cannot share with yourself", json["error"]
  end

  test "fails when required fields are missing" do
    assert_no_difference "Notification.count" do
      post track_shares_path, params: { track_share: @valid_params.merge(title: "") }, as: :json
    end

    assert_response :unprocessable_entity
    json = response.parsed_body
    assert_not json["success"]
    assert_includes json["error"], "Title can't be blank"
  end
end
