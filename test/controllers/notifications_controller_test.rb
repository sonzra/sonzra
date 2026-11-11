require "test_helper"

class NotificationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @notification = notifications(:one)
    @other_user_notification = notifications(:three)
  end

  test "index requires authentication" do
    delete session_path
    get notifications_path
    assert_redirected_to new_session_path
  end

  test "index renders successfully when authenticated" do
    get notifications_path
    assert_response :success
    assert_select "h1", text: /Notifications/
  end

  test "index responds to turbo_stream format" do
    get notifications_path, as: :turbo_stream
    assert_response :success
    assert_includes response.media_type, "text/vnd.turbo-stream.html"
    assert_match %r{<turbo-stream action="update" target="notifications_list">}, response.body
  end

  test "update marks notification as read via turbo stream" do
    assert_nil @notification.read_at

    patch notification_path(@notification), as: :turbo_stream
    assert_response :success
    assert_includes response.media_type, "text/vnd.turbo-stream.html"
    assert_match %r{<turbo-stream action="replace" target="notification_#{@notification.id}">}, response.body
    assert_match %r{<turbo-stream action="update" target="notifications_unread_count">}, response.body

    @notification.reload
    assert_not_nil @notification.read_at
  end

  test "update with redirect_to navigates smoothly" do
    patch notification_path(@notification, redirect_to: "/playlists/123")
    assert_redirected_to "/playlists/123"

    @notification.reload
    assert_not_nil @notification.read_at
  end

  test "update rejects another user's notification" do
    patch notification_path(@other_user_notification), as: :turbo_stream
    assert_response :not_found
  end

  test "mark_all_read marks all unread notifications as read" do
    assert @user.notifications.unread.any?
    assert_nil @other_user_notification.read_at

    post mark_all_read_notifications_path, as: :turbo_stream
    assert_response :success
    assert_includes response.media_type, "text/vnd.turbo-stream.html"
    assert_match %r{<turbo-stream action="update" target="notifications_unread_count">}, response.body

    assert_equal 0, @user.notifications.unread.count
    assert_nil @other_user_notification.reload.read_at
  end

  test "destroy deletes notification via turbo stream" do
    assert_difference "Notification.count", -1 do
      delete notification_path(@notification), as: :turbo_stream
    end
    assert_response :success
    assert_match %r{<turbo-stream action="remove" target="notification_#{@notification.id}">}, response.body
    assert_match %r{<turbo-stream action="update" target="notifications_unread_count">}, response.body
  end

  test "destroy rejects another user's notification" do
    assert_no_difference "Notification.count" do
      delete notification_path(@other_user_notification)
      assert_response :not_found
    end
  end
end
