class AddAnalysisDataToSonicGraphNodes < ActiveRecord::Migration[8.1]
  def change
    add_column :sonic_graph_nodes, :analysis_version, :string
    add_column :sonic_graph_nodes, :feature_vector, :json
  end
end
