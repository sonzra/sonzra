class HiddenGenre < ApplicationRecord
  belongs_to :user
  belongs_to :server_connection

  normalizes :name, with: ->(name) { name.strip }

  validates :name, presence: true
  validates :name, uniqueness: { scope: %i[user_id server_connection_id], case_sensitive: false }
end
