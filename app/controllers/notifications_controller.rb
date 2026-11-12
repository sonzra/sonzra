class NotificationsController < ApplicationController
  before_action :set_notification, only: %i[update read destroy]

  def index
    @notifications = current_user.notifications.recent
    @unread_count = current_user.notifications.unread.count

    respond_to do |format|
      format.html
      format.json { render json: @notifications }
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
    @notification.mark_as_read!
    unread_count = current_user.notifications.unread.count

    respond_to do |format|
      format.html { redirect_back fallback_location: notifications_path }
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace(helpers.dom_id(@notification), partial: "notifications/notification", locals: { notification: @notification }),
          turbo_stream.replace("notifications_badge", partial: "notifications/badge", locals: { count: unread_count })
        ]
      end
      format.json { render json: { success: true, notification: @notification, unread_count: unread_count } }
    end
  end
  alias_method :read, :update

  def mark_all_read
    current_user.notifications.unread.update_all(read_at: Time.current) # rubocop:disable Rails/SkipsModelValidations

    unread_count = current_user.notifications.unread.count
    Turbo::StreamsChannel.broadcast_update_to(
      "user_#{current_user.id}_notifications",
      target: "notifications_badge",
      partial: "notifications/badge",
      locals: { count: unread_count }
    )

    respond_to do |format|
      format.html { redirect_back fallback_location: notifications_path, notice: "All notifications marked as read." }
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace("notifications_badge", partial: "notifications/badge", locals: { count: unread_count }),
          turbo_stream.update("notifications_list", partial: "notifications/notification", collection: current_user.notifications.recent, as: :notification),
          turbo_stream.update("notifications_header_actions", "")
        ]
      end
      format.json { render json: { success: true, unread_count: unread_count } }
    end
  end

  def destroy
    @notification.destroy!
    unread_count = current_user.notifications.unread.count

    respond_to do |format|
      format.html { redirect_back fallback_location: notifications_path }
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.remove(helpers.dom_id(@notification)),
          turbo_stream.replace("notifications_badge", partial: "notifications/badge", locals: { count: unread_count })
        ]
      end
      format.json { render json: { success: true, unread_count: unread_count } }
    end
  end

  private

  def set_notification
    @notification = current_user.notifications.find(params[:id])
  end
end
