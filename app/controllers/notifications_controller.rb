class NotificationsController < ApplicationController
  def index
    @notifications = current_user.notifications.recent

    respond_to do |format|
      format.html
      format.turbo_stream do
        render turbo_stream: turbo_stream.update(
          "notifications_list",
          partial: "notifications/notification",
          collection: @notifications,
          as: :notification
        )
      end
    end
  end

  def update
    @notification = current_user.notifications.find(params[:id])
    @notification.mark_as_read!

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace(helpers.dom_id(@notification), partial: "notifications/notification", locals: { notification: @notification }),
          turbo_stream.update("notifications_unread_count", partial: "notifications/badge", locals: { count: current_user.notifications.unread.count })
        ]
      end
      format.html do
        if params[:redirect_to].present?
          redirect_to params[:redirect_to]
        else
          redirect_back fallback_location: notifications_path
        end
      end
    end
  end

  def mark_all_read
    current_user.notifications.unread.update_all(read_at: Time.current)
    @notifications = current_user.notifications.recent

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.update("notifications_list", partial: "notifications/notification", collection: @notifications, as: :notification),
          turbo_stream.update("notifications_unread_count", partial: "notifications/badge", locals: { count: 0 }),
          turbo_stream.update("notifications_header_actions", "")
        ]
      end
      format.html { redirect_back fallback_location: notifications_path }
    end
  end

  def destroy
    @notification = current_user.notifications.find(params[:id])
    @notification.destroy!

    respond_to do |format|
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.remove(helpers.dom_id(@notification)),
          turbo_stream.update("notifications_unread_count", partial: "notifications/badge", locals: { count: current_user.notifications.unread.count })
        ]
      end
      format.html { redirect_back fallback_location: notifications_path }
    end
  end
end
