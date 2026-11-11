require "test_helper"

class NotificationTest < ActiveSupport::TestCase
  setup do
    @sender = users(:one)
    @recipient = users(:two)
  end

  test "valid notification creates successfully" do
    notification = Notification.new(
      recipient: @recipient,
      sender: @sender,
      title: "Bohemian Rhapsody",
      artist: "Queen",
      album: "A Night at the Opera",
      item_id: "track-123",
      notification_type: "track_share",
      note: "Check out the guitar solo!"
    )

    assert notification.valid?
    assert notification.save
    assert notification.unread?
    assert_not notification.read?
  end

  test "requires recipient, title, item_id, and notification_type" do
    notification = Notification.new(notification_type: nil)
    assert_not notification.valid?
    assert_includes notification.errors[:recipient], "must exist"
    assert_includes notification.errors[:title], "can't be blank"
    assert_includes notification.errors[:item_id], "can't be blank"
    assert_includes notification.errors[:notification_type], "can't be blank"
  end

  test "note length cannot exceed 280 characters" do
    notification = Notification.new(
      recipient: @recipient,
      sender: @sender,
      title: "Track",
      item_id: "123",
      note: "a" * 281
    )

    assert_not notification.valid?
    assert_includes notification.errors[:note], "is too long (maximum is 280 characters)"

    notification.note = "a" * 280
    assert notification.valid?
  end

  test "sender cannot be recipient" do
    notification = Notification.new(
      recipient: @sender,
      sender: @sender,
      title: "Track",
      item_id: "123"
    )

    assert_not notification.valid?
    assert_includes notification.errors[:recipient], "cannot share with yourself"
  end

  test "sender is optional" do
    notification = Notification.new(
      recipient: @recipient,
      sender: nil,
      title: "System announcement",
      item_id: "track-sys",
      notification_type: "system"
    )

    assert notification.valid?
  end

  test "scopes filter by read status and order recent" do
    n1 = Notification.create!(
      recipient: @recipient,
      sender: @sender,
      title: "Track 1",
      item_id: "1",
      created_at: 2.hours.ago,
      read_at: 1.hour.ago
    )
    n2 = Notification.create!(
      recipient: @recipient,
      sender: @sender,
      title: "Track 2",
      item_id: "2",
      created_at: 1.hour.ago,
      read_at: nil
    )
    n3 = Notification.create!(
      recipient: @recipient,
      sender: @sender,
      title: "Track 3",
      item_id: "3",
      created_at: 10.minutes.ago,
      read_at: nil
    )

    unread_notifications = @recipient.notifications.unread
    assert_includes unread_notifications, n2
    assert_includes unread_notifications, n3
    assert_not_includes unread_notifications, n1

    read_notifications = @recipient.notifications.read
    assert_includes read_notifications, n1
    assert_not_includes read_notifications, n2
    assert_not_includes read_notifications, n3

    recent_notifications = @recipient.notifications.recent
    assert_equal [ n3, n2, n1 ], recent_notifications.to_a
  end

  test "mark_as_read! updates read_at timestamp" do
    notification = Notification.create!(
      recipient: @recipient,
      sender: @sender,
      title: "Track",
      item_id: "123"
    )

    assert notification.unread?
    freeze_time do
      notification.mark_as_read!
      assert notification.read?
      assert_equal Time.current, notification.read_at
    end
  end

  test "user has_many notifications and sent_notifications" do
    notification = Notification.create!(
      recipient: @recipient,
      sender: @sender,
      title: "Track",
      item_id: "123"
    )

    assert_includes @recipient.notifications, notification
    assert_includes @sender.sent_notifications, notification

    assert_difference("Notification.count", -1) do
      @recipient.destroy
    end
  end
end
