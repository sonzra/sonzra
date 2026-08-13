class HiddenArtist < ApplicationRecord
  belongs_to :user
  belongs_to :server_connection

  validates :artist_id, :name, presence: true
  validates :artist_id, uniqueness: { scope: %i[user_id server_connection_id] }
end
