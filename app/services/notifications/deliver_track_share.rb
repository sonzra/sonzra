module Notifications
  class DeliverTrackShare
    Result = Data.define(:success?, :notification, :error) do
      def success
        success?
      end

      def errors
        error ? [ error ] : []
      end
    end

    def self.call(...)
      new(...).call
    end

    def initialize(sender:, recipient_id: nil, recipient: nil, params: nil, track_params: nil)
      @sender = sender
      @recipient = recipient || (User.find_by(id: recipient_id) if recipient_id.present?)
      @params = (params || track_params || {}).to_h.symbolize_keys
    end

    def call
      return Result.new(success?: false, notification: nil, error: "Recipient not found") unless @recipient
      return Result.new(success?: false, notification: nil, error: "Cannot share with yourself") if @recipient == @sender

      notification = Notification.create!(
        recipient: @recipient,
        sender: @sender,
        media_server_id: @params[:media_server_id],
        notification_type: "track_share",
        title: @params[:title],
        artist: @params[:artist],
        album: @params[:album],
        item_id: @params[:item_id],
        artwork_item_id: @params[:artwork_item_id],
        note: @params[:note]
      )

      broadcast_delivery(notification, @recipient)
      Result.new(success?: true, notification: notification, error: nil)
    rescue ActiveRecord::RecordInvalid => e
      Result.new(success?: false, notification: nil, error: e.record.errors.full_messages.to_sentence)
    end

    private

    def broadcast_delivery(notification, recipient)
      Turbo::StreamsChannel.broadcast_prepend_to(
        [ recipient, :notifications ],
        target: "notifications_list",
        partial: "notifications/notification",
        locals: { notification: notification, current_user: recipient }
      )

      Turbo::StreamsChannel.broadcast_replace_to(
        [ recipient, :notifications ],
        target: "notifications_badge",
        partial: "notifications/badge",
        locals: { count: recipient.notifications.unread.count }
      )
    end
  end
end
