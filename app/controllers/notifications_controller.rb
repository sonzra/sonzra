class NotificationsController < ApplicationController
  before_action :set_notification, only: %i[update read]

  def index
    @notifications = current_user.notifications.recent
    @unread_count = current_user.notifications.unread.count

    respond_to do |format|
      format.html
      format.json { render json: @notifications }
    end
  end

  def update
    @notification.mark_as_read!
    unread_count = current_user.notifications.unread.count

    respond_to do |format|
      format.html { redirect_back fallback_location: notifications_path }
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace(ActionView::RecordIdentifier.dom_id(@notification), partial: "notifications/notification", locals: { notification: @notification, current_user: current_user }),
          turbo_stream.replace("notifications_badge", partial: "notifications/badge", locals: { count: unread_count })
        ]
      end
      format.json { render json: { success: true, notification: @notification, unread_count: unread_count } }
    end
  end
  alias_method :read, :update

  def mark_all_read
    current_user.notifications.unread.update_all(read_at: Time.current) # rubocop:disable Rails/SkipsModelValidations

    Turbo::StreamsChannel.broadcast_replace_to(
      [ current_user, :notifications ],
      target: "notifications_badge",
      partial: "notifications/badge",
      locals: { count: 0 }
    )

    respond_to do |format|
      format.html { redirect_back fallback_location: notifications_path, notice: "All notifications marked as read." }
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.replace("notifications_badge", partial: "notifications/badge", locals: { count: 0 }),
          turbo_stream.replace("notifications_list", partial: "notifications/list", locals: { notifications: current_user.notifications.recent, current_user: current_user })
        ]
      end
      format.json { render json: { success: true, unread_count: 0 } }
    end
  end

  private

  def set_notification
    @notification = current_user.notifications.find(params[:id])
  end
end
