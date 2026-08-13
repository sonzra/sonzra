class RecommendationRun < ApplicationRecord
  belongs_to :user
  belongs_to :server_connection, optional: true
  belongs_to :recommendation_collection, optional: true

  validates :strategy, inclusion: { in: RecommendationCollection::STRATEGIES }
  validates :period_date, :status, presence: true
end
