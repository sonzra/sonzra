require "test_helper"

class NotificationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @other_user = users(:two)

    @user_notification = Notification.create!(
      recipient: @user,
      sender: @other_user,
      title: "User Track",
      item_id: "track-1",
      created_at: 10.minutes.ago
    )

    @other_notification = Notification.create!(
      recipient: @other_user,
      sender: @user,
      title: "Other User Track",
      item_id: "track-2",
      created_at: 5.minutes.ago
    )
  end

  test "index renders notifications for current user only" do
    get notifications_path
    assert_response :success
    assert_includes response.body, "User Track"
    assert_not_includes response.body, "Other User Track"
  end

  test "index returns json format for current user" do
    get notifications_path, as: :json
    assert_response :success
    json = response.parsed_body
    assert_equal 1, json.length
    assert_equal "User Track", json.first["title"]
  end

  test "update marks single notification as read" do
    assert @user_notification.unread?

    patch notification_path(@user_notification), as: :json
    assert_response :success
    assert @user_notification.reload.read?

    json = response.parsed_body
    assert json["success"]
    assert_equal 0, json["unread_count"]
  end

  test "update supports turbo stream response" do
    patch notification_path(@user_notification), as: :turbo_stream
    assert_response :success
    assert_includes response.media_type, "text/vnd.turbo-stream.html"
    assert_includes response.body, %(target="notification_#{@user_notification.id}")
    assert_includes response.body, %(target="notifications_badge")
  end

  test "read member route also marks notification as read" do
    patch read_notification_path(@user_notification), as: :json
    assert_response :success
    assert @user_notification.reload.read?
  end

  test "cannot mark another user's notification as read" do
    patch notification_path(@other_notification)
    assert_response :not_found
    assert @other_notification.reload.unread?
  end

  test "mark_all_read marks all unread notifications as read for current user" do
    second_notification = Notification.create!(
      recipient: @user,
      sender: @other_user,
      title: "Second Track",
      item_id: "track-3"
    )

    assert_equal 2, @user.notifications.unread.count
    assert_equal 1, @other_user.notifications.unread.count

    post mark_all_read_notifications_path, as: :json
    assert_response :success

    assert_equal 0, @user.notifications.unread.count
    assert_equal 1, @other_user.notifications.unread.count
  end

  test "mark_all_read supports turbo stream response" do
    post mark_all_read_notifications_path, as: :turbo_stream
    assert_response :success
    assert_includes response.media_type, "text/vnd.turbo-stream.html"
    assert_includes response.body, %(target="notifications_badge")
    assert_includes response.body, %(target="notifications_list")
  end
end
