class Notification < ApplicationRecord
  belongs_to :user, inverse_of: :notifications
  belongs_to :actor_user, class_name: "User", optional: true, inverse_of: :sent_notifications
  belongs_to :media_server, optional: true

  scope :unread, -> { where(read_at: nil) }
  scope :read, -> { where.not(read_at: nil) }
  scope :recent, -> { order(created_at: :desc).limit(30) }

  validates :title, :message, :notification_type, presence: true
  validates :item_id, presence: true, if: :track_share?
  validates :note, length: { maximum: 280 }, allow_blank: true
  validate :sender_cannot_be_recipient, if: :track_share?

  def read?
    read_at.present?
  end

  def unread?
    !read?
  end

  def mark_as_read!
    update!(read_at: Time.current) if unread?
  end

  def recipient
    user
  end

  def recipient=(value)
    self.user = value
  end

  def recipient_id
    user_id
  end

  def recipient_id=(value)
    self.user_id = value
  end

  def sender
    actor_user
  end

  def sender=(value)
    self.actor_user = value
  end

  def sender_id
    actor_user_id
  end

  def sender_id=(value)
    self.actor_user_id = value
  end

  private

  def track_share?
    notification_type == "track_share"
  end

  def sender_cannot_be_recipient
    errors.add(:recipient, "cannot share with yourself") if actor_user_id.present? && actor_user_id == user_id
  end
end
