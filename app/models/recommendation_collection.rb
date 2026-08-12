class RecommendationCollection < ApplicationRecord
  STRATEGIES = %w[friday_rediscovery best_of_genre more_from_artist top_of_month].freeze

  belongs_to :user
  belongs_to :server_connection
  has_many :recommendation_tracks, -> { order(:position) }, dependent: :destroy
  has_many :recommendation_collection_events, dependent: :destroy

  validates :strategy, inclusion: { in: STRATEGIES }
  validates :period_date, :title, :subtitle, :generated_at, presence: true
end
