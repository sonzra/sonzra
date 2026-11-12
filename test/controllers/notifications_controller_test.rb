require "test_helper"

class NotificationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @other_user = users(:two)
    @notification = notifications(:one)
    @other_user_notification = notifications(:three)
  end

  test "index renders notifications for current user only" do
    track_notification = Notification.create!(
      recipient: @user,
      sender: @other_user,
      notification_type: "track_share",
      title: "User Track",
      message: "Shared a track with you",
      item_id: "track-1"
    )

    get notifications_path

    assert_response :success
    assert_select "h1", text: /Notifications/
    assert_includes response.body, "Playlist shared"
    assert_includes response.body, "User Track"
    assert_not_includes response.body, "Mix ready"
    assert_includes response.body, %(id="notification_#{track_notification.id}")
  end

  test "index returns JSON for the current user" do
    get notifications_path, as: :json

    assert_response :success
    assert response.parsed_body.any? { |notification| notification["title"] == "Playlist shared" }
    assert response.parsed_body.none? { |notification| notification["title"] == "Mix ready" }
  end

  test "index responds to Turbo Streams" do
    get notifications_path, as: :turbo_stream

    assert_response :success
    assert_includes response.media_type, "text/vnd.turbo-stream.html"
    assert_match %r{<turbo-stream action="update" target="notifications_list">}, response.body
  end

  test "update marks a notification as read" do
    assert @notification.unread?

    patch notification_path(@notification), as: :json

    assert_response :success
    assert @notification.reload.read?
    assert response.parsed_body["success"]
    assert_equal 0, @user.notifications.unread.count
  end

  test "update supports Turbo Stream response" do
    patch notification_path(@notification), as: :turbo_stream

    assert_response :success
    assert_includes response.media_type, "text/vnd.turbo-stream.html"
    assert_includes response.body, %(target="notification_#{@notification.id}")
    assert_includes response.body, %(target="notifications_badge")
  end

  test "read member route also marks the notification as read" do
    patch read_notification_path(@notification), as: :json

    assert_response :success
    assert @notification.reload.read?
  end

  test "cannot update or dismiss another user's notification" do
    patch notification_path(@other_user_notification)
    assert_response :not_found

    assert_no_difference "Notification.count" do
      delete notification_path(@other_user_notification)
    end
    assert_response :not_found
  end

  test "mark_all_read marks all unread notifications for the current user" do
    Notification.create!(
      recipient: @user,
      notification_type: "track_share",
      title: "Second Track",
      message: "Shared a track with you",
      item_id: "track-2"
    )

    assert_equal 2, @user.notifications.unread.count
    assert_equal 1, @other_user.notifications.unread.count

    post mark_all_read_notifications_path, as: :json

    assert_response :success
    assert_equal 0, @user.notifications.unread.count
    assert_equal 1, @other_user.notifications.unread.count
  end

  test "mark_all_read supports Turbo Stream response" do
    post mark_all_read_notifications_path, as: :turbo_stream

    assert_response :success
    assert_includes response.media_type, "text/vnd.turbo-stream.html"
    assert_includes response.body, %(target="notifications_badge")
    assert_includes response.body, %(target="notifications_list")
  end

  test "destroy removes a notification via Turbo Stream" do
    assert_difference "Notification.count", -1 do
      delete notification_path(@notification), as: :turbo_stream
    end

    assert_response :success
    assert_match %r{<turbo-stream action="remove" target="notification_#{@notification.id}">}, response.body
    assert_match %r{<turbo-stream action="replace" target="notifications_badge">}, response.body
  end
end
