class CreateRecommendationCollectionEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :recommendation_collection_events do |t|
      t.references :recommendation_collection, null: false, foreign_key: true
      t.string :event_type, null: false
      t.datetime :occurred_at, null: false
      t.timestamps
    end
    add_index :recommendation_collection_events, %i[recommendation_collection_id event_type], name: "index_recommendation_events_on_collection_and_type"
  end
end
