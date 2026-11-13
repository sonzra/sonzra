require "test_helper"

class NotificationTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @actor = users(:two)
  end

  test "valid generic notification" do
    notification = Notification.new(
      user: @user,
      actor_user: @actor,
      title: "New Playlist",
      message: "Check it out",
      link_url: "/playlists/1"
    )

    assert notification.valid?
  end

  test "valid track share notification" do
    notification = Notification.new(
      recipient: @user,
      sender: @actor,
      notification_type: "track_share",
      title: "Bohemian Rhapsody",
      message: "Shared a track with you",
      artist: "Queen",
      album: "A Night at the Opera",
      item_id: "track-123",
      note: "Check out the guitar solo!"
    )

    assert notification.valid?
    assert notification.save
    assert notification.unread?
    assert_not notification.read?
  end

  test "requires a title and message" do
    notification = Notification.new(user: @user)

    assert_not notification.valid?
    assert_includes notification.errors[:title], "can't be blank"
    assert_includes notification.errors[:message], "can't be blank"
  end

  test "requires track item ID for track shares" do
    notification = Notification.new(
      recipient: @user,
      title: "Track",
      message: "Shared a track with you",
      notification_type: "track_share"
    )

    assert_not notification.valid?
    assert_includes notification.errors[:item_id], "can't be blank"
  end

  test "note length cannot exceed 280 characters" do
    notification = Notification.new(
      recipient: @user,
      sender: @actor,
      notification_type: "track_share",
      title: "Track",
      message: "Shared a track with you",
      item_id: "123",
      note: "a" * 281
    )

    assert_not notification.valid?
    assert_includes notification.errors[:note], "is too long (maximum is 280 characters)"

    notification.note = "a" * 280
    assert notification.valid?
  end

  test "track sender cannot be recipient" do
    notification = Notification.new(
      recipient: @user,
      sender: @user,
      notification_type: "track_share",
      title: "Track",
      message: "Shared a track with you",
      item_id: "123"
    )

    assert_not notification.valid?
    assert_includes notification.errors[:recipient], "cannot share with yourself"
  end

  test "sender is optional" do
    notification = Notification.new(
      recipient: @user,
      title: "System announcement",
      message: "A new update is available",
      item_id: "track-sys",
      notification_type: "system"
    )

    assert notification.valid?
  end

  test "scopes filter by read status and order recent" do
    older = Notification.create!(
      user: @user,
      title: "Old",
      message: "Old notification",
      created_at: 2.hours.ago,
      read_at: 1.hour.ago
    )
    recent_unread = Notification.create!(
      user: @user,
      title: "Recent",
      message: "Unread notification",
      created_at: 10.minutes.ago
    )
    newer_unread = Notification.create!(
      user: @user,
      title: "Newer",
      message: "Newest notification",
      created_at: 1.minute.ago
    )

    assert_includes @user.notifications.unread, recent_unread
    assert_includes @user.notifications.unread, newer_unread
    assert_includes @user.notifications.read, older
    assert_equal @user.notifications.order(created_at: :desc).limit(30), @user.notifications.recent
  end

  test "mark_as_read! updates read_at timestamp" do
    notification = notifications(:one)

    freeze_time do
      notification.mark_as_read!
      assert notification.read?
      assert_equal Time.current, notification.read_at
    end
  end

  test "user associations include received and sent track shares" do
    notification = Notification.create!(
      recipient: @user,
      sender: @actor,
      notification_type: "track_share",
      title: "Track",
      message: "Shared a track with you",
      item_id: "123"
    )

    assert_includes @user.notifications, notification
    assert_includes @actor.sent_notifications, notification

    received_notification_count = @user.notifications.count
    assert_difference("Notification.count", -received_notification_count) do
      @user.destroy
    end
  end

  test "deleting an actor preserves their notification" do
    notification = notifications(:one)

    @actor.destroy

    assert_nil notification.reload.actor_user
  end

  test "DeliverNotification creates notification and broadcasts to Turbo Streams" do
    broadcasts = []
    singleton = Turbo::StreamsChannel.singleton_class
    original_prepend = Turbo::StreamsChannel.method(:broadcast_prepend_to)
    original_update = Turbo::StreamsChannel.method(:broadcast_update_to)

    singleton.define_method(:broadcast_prepend_to) do |stream, **options|
      broadcasts << { type: :prepend, stream: stream, **options }
    end
    singleton.define_method(:broadcast_update_to) do |stream, **options|
      broadcasts << { type: :update, stream: stream, **options }
    end

    notification = Notifications::DeliverNotification.new(
      @user,
      title: "Collaborative Playlist",
      message: "Alex invited you to edit Road Trip",
      link_url: "/playlists/99",
      actor_user: @actor
    ).call

    assert notification.persisted?
    assert_equal "Collaborative Playlist", notification.title
    assert_equal @actor, notification.actor_user
    assert_equal 2, broadcasts.size

    prepend_call = broadcasts.find { |broadcast| broadcast[:target] == "notifications_list" }
    assert_equal "user_#{@user.id}_notifications", prepend_call[:stream]
    badge_call = broadcasts.find { |broadcast| broadcast[:target] == "notifications_badge" }
    assert_equal "user_#{@user.id}_notifications", badge_call[:stream]
  ensure
    singleton&.define_method(:broadcast_prepend_to, original_prepend)
    singleton&.define_method(:broadcast_update_to, original_update)
  end
end
