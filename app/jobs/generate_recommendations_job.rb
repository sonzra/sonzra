class GenerateRecommendationsJob < ApplicationJob
  queue_as :default

  def perform(period_date = Date.current)
    User.find_each do |user|
      RecommendationGenerator.ensure_all(user:, period_date:)
    end
  end
end
