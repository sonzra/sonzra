class RecommendationCollectionEvent < ApplicationRecord
  belongs_to :recommendation_collection

  validates :event_type, inclusion: { in: %w[started] }
  validates :occurred_at, presence: true
end
