class SonicGraphNode < ApplicationRecord
  belongs_to :server_connection

  validates :item_id, :title, presence: true
  validates :item_id, uniqueness: { scope: :server_connection_id }
end
