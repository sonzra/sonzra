class GenerateRecommendationsJob < ApplicationJob
  queue_as :default

  def perform(period_date = Date.current)
    RecommendationCollection::STRATEGIES.each do |strategy|
      next unless RecommendationGenerator.scheduled?(strategy, period_date)

      User.find_each do |user|
        RecommendationGenerator.new(user:, strategy:, period_date:).call
      end
    end
  end
end
