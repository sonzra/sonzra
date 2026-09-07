class AddAnalysisVersionToTrackSimilarities < ActiveRecord::Migration[8.1]
  def change
    add_column :track_similarities, :analysis_version, :string
    add_index :track_similarities, [ :server_connection_id, :analysis_version ], name: :index_track_similarities_on_connection_and_analysis_version
  end
end
