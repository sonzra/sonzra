class BuildSonicGraphJob < ApplicationJob
  queue_as :default

  def perform(connection_or_id = nil)
    if connection_or_id.nil?
      logger.info("[SonicGraph] Starting BuildSonicGraphJob for all server connections...")
      ServerConnection.find_each do |connection|
        SonicGraph::Builder.new(connection, logger:).call
      end
      logger.info("[SonicGraph] Finished BuildSonicGraphJob for all server connections.")
    else
      connection = connection_or_id.is_a?(ServerConnection) ? connection_or_id : ServerConnection.find(connection_or_id)
      SonicGraph::Builder.new(connection, logger:).call
    end
  end
end
