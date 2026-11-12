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

      media_server_id = resolve_media_server_id
      artwork_item_id = resolve_artwork_item_id

      notification = Notification.create!(
        recipient: @recipient,
        sender: @sender,
        media_server_id: media_server_id,
        notification_type: "track_share",
        title: @params[:title],
        message: "Shared a track with you",
        artist: @params[:artist],
        album: @params[:album],
        item_id: @params[:item_id],
        artwork_item_id: artwork_item_id,
        note: @params[:note]
      )

      broadcast_delivery(notification, @recipient)
      Result.new(success?: true, notification: notification, error: nil)
    rescue ActiveRecord::RecordInvalid => e
      Result.new(success?: false, notification: nil, error: e.record.errors.full_messages.to_sentence)
    rescue ActiveRecord::InvalidForeignKey => e
      Rails.logger.warn("Foreign key error in DeliverTrackShare: #{e.message}")
      Result.new(success?: false, notification: nil, error: "Invalid media server reference")
    end

    private

    def resolve_media_server_id
      raw_media_server_id = @params[:media_server_id].presence
      raw_connection_id = @params[:server_connection_id].presence

      # 1. Try finding by explicit media_server_id if it exists in MediaServer table
      if raw_media_server_id && MediaServer.exists?(id: raw_media_server_id)
        return raw_media_server_id.to_i
      end

      # 2. Check if raw_media_server_id or raw_connection_id is actually a server_connection_id
      candidate_ids = [ raw_connection_id, raw_media_server_id ].compact
      candidate_ids.each do |conn_id|
        conn = @sender&.server_connections&.find_by(id: conn_id) || ServerConnection.find_by(id: conn_id)
        return conn.media_server_id if conn&.media_server_id.present?
      end

      # 3. Fallback to sender's preferred or first server connection
      fallback_conn = @sender&.preferred_server_connection || @sender&.server_connections&.first
      return fallback_conn.media_server_id if fallback_conn&.media_server_id.present?

      nil
    end

    def resolve_artwork_item_id
      raw = @params[:artwork_item_id].presence
      return nil if raw.blank?

      if raw.include?("/artwork/")
        raw.split("/artwork/").last.split("?").first
      else
        raw
      end
    end

    def broadcast_delivery(notification, recipient)
      Turbo::StreamsChannel.broadcast_prepend_to(
        "user_#{recipient.id}_notifications",
        target: "notifications_list",
        partial: "notifications/notification",
        locals: { notification: notification, current_user: recipient }
      )

      Turbo::StreamsChannel.broadcast_replace_to(
        "user_#{recipient.id}_notifications",
        target: "notifications_badge",
        partial: "notifications/badge",
        locals: { count: recipient.notifications.unread.count }
      )
    end
  end
end
