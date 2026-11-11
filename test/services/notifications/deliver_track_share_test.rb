require "test_helper"

module Notifications
  class DeliverTrackShareTest < ActiveSupport::TestCase
    include ActionCable::TestHelper

    setup do
      @sender = users(:one)
      @recipient = users(:two)
      @valid_params = {
        title: "Starman",
        artist: "David Bowie",
        album: "The Rise and Fall of Ziggy Stardust",
        item_id: "track-456",
        artwork_item_id: "art-456",
        note: "Listen to the chorus!"
      }
    end

    test "successfully creates notification and broadcasts to recipient stream" do
      stream = Turbo::StreamsChannel.send(:stream_name_from, [ @recipient, :notifications ])

      result = nil
      assert_difference -> { @recipient.notifications.count } => 1, -> { @sender.sent_notifications.count } => 1 do
        assert_broadcasts(stream, 2) do
          result = DeliverTrackShare.call(
            sender: @sender,
            recipient_id: @recipient.id,
            params: @valid_params
          )
        end
      end

      assert result.success?
      assert_nil result.error
      assert_equal "Starman", result.notification.title
      assert_equal "David Bowie", result.notification.artist
      assert_equal "The Rise and Fall of Ziggy Stardust", result.notification.album
      assert_equal "track-456", result.notification.item_id
      assert_equal "art-456", result.notification.artwork_item_id
      assert_equal "Listen to the chorus!", result.notification.note
      assert result.notification.unread?
    end

    test "fails when recipient is not found" do
      result = DeliverTrackShare.call(
        sender: @sender,
        recipient_id: 999_999,
        params: @valid_params
      )

      assert_not result.success?
      assert_nil result.notification
      assert_equal "Recipient not found", result.error
    end

    test "fails when sender attempts to share with themselves" do
      result = DeliverTrackShare.call(
        sender: @sender,
        recipient_id: @sender.id,
        params: @valid_params
      )

      assert_not result.success?
      assert_nil result.notification
      assert_equal "Cannot share with yourself", result.error
    end

    test "fails with validation error when title is missing" do
      invalid_params = @valid_params.merge(title: "")

      result = DeliverTrackShare.call(
        sender: @sender,
        recipient_id: @recipient.id,
        params: invalid_params
      )

      assert_not result.success?
      assert_nil result.notification
      assert_includes result.error, "Title can't be blank"
    end

    test "fails with validation error when note exceeds 280 characters" do
      invalid_params = @valid_params.merge(note: "x" * 281)

      result = DeliverTrackShare.call(
        sender: @sender,
        recipient_id: @recipient.id,
        params: invalid_params
      )

      assert_not result.success?
      assert_nil result.notification
      assert_includes result.error, "Note is too long"
    end
  end
end
