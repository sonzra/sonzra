class ListeningEvent < ApplicationRecord
  belongs_to :user
  belongs_to :server_connection

  validates :item_id, :occurred_at, presence: true
end
