require "test_helper"

class NotificationTest < ActiveSupport::TestCase
  setup do
    @user = users(:one)
    @actor = users(:two)
  end

  test "valid notification" do
    notification = Notification.new(
      user: @user,
      actor_user: @actor,
      title: "New Playlist",
      message: "Check it out",
      link_url: "/playlists/1"
    )
    assert notification.valid?
  end

  test "invalid without title or message" do
    notification = Notification.new(user: @user)
    assert_not notification.valid?
    assert_includes notification.errors[:title], "can't be blank"
    assert_includes notification.errors[:message], "can't be blank"
  end

  test "read? and mark_as_read!" do
    notification = notifications(:one)
    assert_not notification.read?

    notification.mark_as_read!
    assert notification.read?
    assert_not_nil notification.read_at
  end

  test "unread and recent scopes" do
    unread = @user.notifications.unread
    assert_includes unread, notifications(:one)
    assert_not_includes unread, notifications(:two)

    recent = @user.notifications.recent
    assert_equal @user.notifications.order(created_at: :desc).limit(30), recent
  end

  test "dependent destroy on user" do
    notification = notifications(:three)
    target_user = users(:two)

    assert_difference "Notification.count", -1 do
      target_user.destroy
    end
    assert_not Notification.exists?(notification.id)
  end

  test "DeliverNotification creates notification and broadcasts to Turbo Streams" do
    broadcasts = []
    singleton = Turbo::StreamsChannel.singleton_class
    orig_prepend = Turbo::StreamsChannel.method(:broadcast_prepend_to)
    orig_update = Turbo::StreamsChannel.method(:broadcast_update_to)

    singleton.define_method(:broadcast_prepend_to) do |stream, **options|
      broadcasts << { type: :prepend, stream: stream, **options }
    end
    singleton.define_method(:broadcast_update_to) do |stream, **options|
      broadcasts << { type: :update, stream: stream, **options }
    end

    begin
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

      prepend_call = broadcasts.find { |b| b[:target] == "notifications_list" }
      assert_not_nil prepend_call
      assert_equal "user_#{@user.id}_notifications", prepend_call[:stream]

      badge_call = broadcasts.find { |b| b[:target] == "notifications_unread_count" }
      assert_not_nil badge_call
      assert_equal "user_#{@user.id}_notifications", badge_call[:stream]
    ensure
      singleton.define_method(:broadcast_prepend_to, orig_prepend)
      singleton.define_method(:broadcast_update_to, orig_update)
    end
  end
end
