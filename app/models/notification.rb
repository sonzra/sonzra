class Notification < ApplicationRecord
  belongs_to :user
  belongs_to :actor_user, class_name: "User", optional: true

  validates :title, :message, presence: true

  scope :unread, -> { where(read_at: nil) }
  scope :recent, -> { order(created_at: :desc).limit(30) }

  def read?
    read_at.present?
  end

  def unread?
    !read?
  end

  def mark_as_read!
    update!(read_at: Time.current)
  end
end
