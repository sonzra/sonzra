namespace :sonic_graph do
  desc "Backfill sonic similarity graph for connections without data"
  task backfill: :environment do
    ServerConnection.find_each do |connection|
      if TrackSimilarity.where(server_connection: connection).exists?
        puts "Skipping connection ##{connection.id} (#{connection.name}) — already has graph data"
        next
      end
      BuildSonicGraphJob.perform_later(connection.id)
      puts "Enqueued graph build for connection ##{connection.id} (#{connection.name})"
    end
  end

  desc "Force rebuild and sync metadata for all server connections"
  task rebuild: :environment do
    ServerConnection.find_each do |connection|
      puts "Building sonic graph and caching metadata for connection ##{connection.id} (#{connection.name})..."
      SonicGraph::Builder.new(connection).call
    end
  end
end
