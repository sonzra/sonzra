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

  desc "Prune non-music tracks (podcasts/audiobooks) from existing similarity graphs"
  task prune_non_music: :environment do
    ServerConnection.find_each do |connection|
      client = begin
        Integrations::Client.for(connection)
      rescue Integrations::Jellyfin::Client::ConnectionError, Integrations::Plex::Client::ConnectionError => e
        puts "Skipping connection ##{connection.id} (#{connection.name}): #{e.message}"
        next
      end

      next unless client.supports?(Integrations::Capabilities::SONIC_GRAPH)

      music_track_ids = Set.new(client.all_track_ids.map(&:to_s))
      existing_nodes = SonicGraphNode.where(server_connection: connection).pluck(:item_id)
      non_music_ids = existing_nodes.reject { |id| music_track_ids.include?(id.to_s) }

      if non_music_ids.empty?
        puts "Connection ##{connection.id} (#{connection.name}): No non-music tracks to prune."
        next
      end

      puts "Connection ##{connection.id} (#{connection.name}): Pruning #{non_music_ids.size} non-music nodes and associated edges..."
      non_music_ids.each do |item_id|
        TrackSimilarity.prune_item!(connection, item_id)
      end
      SonicGraphNode.where(server_connection: connection, item_id: non_music_ids).delete_all
      puts "Connection ##{connection.id} (#{connection.name}): Pruning complete."
    end
    Rails.cache.delete_matched("sonic_graph_v2*")
  end
end
