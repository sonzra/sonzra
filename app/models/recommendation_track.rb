class RecommendationTrack < ApplicationRecord
  belongs_to :recommendation_collection

  validates :item_id, :position, :title, presence: true
end
