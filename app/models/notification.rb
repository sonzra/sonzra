class Notification < ApplicationRecord
  belongs_to :recipient, class_name: "User"
  belongs_to :sender, class_name: "User", optional: true
  belongs_to :media_server, optional: true

  scope :unread, -> { where(read_at: nil) }
  scope :read, -> { where.not(read_at: nil) }
  scope :recent, -> { order(created_at: :desc) }

  validates :title, :item_id, :notification_type, presence: true
  validates :note, length: { maximum: 280 }, allow_blank: true
  validate :sender_cannot_be_recipient

  def read?
    read_at.present?
  end

  def unread?
    !read?
  end

  def mark_as_read!
    update!(read_at: Time.current) if unread?
  end

  private

  def sender_cannot_be_recipient
    errors.add(:recipient, "cannot share with yourself") if sender_id.present? && sender_id == recipient_id
  end
end
