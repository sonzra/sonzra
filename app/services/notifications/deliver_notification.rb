module Notifications
  class DeliverNotification
    def initialize(user, title:, message:, link_url: nil, actor_user: nil)
      @user = user
      @title = title
      @message = message
      @link_url = link_url
      @actor_user = actor_user
    end

    def call
      notification = @user.notifications.create!(
        title: @title,
        message: @message,
        link_url: @link_url,
        actor_user: @actor_user
      )

      broadcast_realtime(notification)
      notification
    end

    private

    def broadcast_realtime(notification)
      Turbo::StreamsChannel.broadcast_prepend_to(
        "user_#{@user.id}_notifications",
        target: "notifications_list",
        partial: "notifications/notification",
        locals: { notification: notification }
      )

      Turbo::StreamsChannel.broadcast_update_to(
        "user_#{@user.id}_notifications",
        target: "notifications_unread_count",
        partial: "notifications/badge",
        locals: { count: @user.notifications.unread.count }
      )
    end
  end
end
