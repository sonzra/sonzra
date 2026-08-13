class ScopeRecommendationsToServerConnections < ActiveRecord::Migration[8.1]
  def up
    add_reference :recommendation_runs, :server_connection, foreign_key: true

    execute <<~SQL.squish
      UPDATE recommendation_runs
      SET server_connection_id = recommendation_collections.server_connection_id
      FROM recommendation_collections
      WHERE recommendation_runs.recommendation_collection_id = recommendation_collections.id
    SQL

    remove_index :recommendation_collections, name: "index_recommendations_on_user_strategy_period"
    add_index :recommendation_collections, %i[user_id server_connection_id strategy period_date], unique: true, name: "index_recommendations_on_user_connection_strategy_period"
    remove_index :recommendation_runs, name: "index_recommendation_runs_on_user_strategy_period"
    add_index :recommendation_runs, %i[user_id server_connection_id strategy period_date], unique: true, name: "index_recommendation_runs_on_user_connection_strategy_period"
  end

  def down
    remove_index :recommendation_runs, name: "index_recommendation_runs_on_user_connection_strategy_period"
    add_index :recommendation_runs, %i[user_id strategy period_date], unique: true, name: "index_recommendation_runs_on_user_strategy_period"
    remove_index :recommendation_collections, name: "index_recommendations_on_user_connection_strategy_period"
    add_index :recommendation_collections, %i[user_id strategy period_date], unique: true, name: "index_recommendations_on_user_strategy_period"
    remove_reference :recommendation_runs, :server_connection, foreign_key: true
  end
end
