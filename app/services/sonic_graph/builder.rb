module SonicGraph
  class Builder
    BATCH_SIZE = 50
    SIMILAR_LIMIT = 20

    def initialize(connection, client: nil, logger: Rails.logger)
      @connection = connection
      @client = client
      @logger = logger
    end

    def call
      log_info "Starting sonic graph build for connection ##{@connection.id} (#{@connection.name})"

      unless client.supports?(Integrations::Capabilities::SONIC_GRAPH)
        log_info "Connection ##{@connection.id} (#{@connection.name}) provider does not support sonic graph. Skipping."
        return
      end

      track_ids = client.all_track_ids
      if track_ids.empty?
        log_info "No tracks found for connection ##{@connection.id} (#{@connection.name})."
        return
      end

      total_tracks = track_ids.size
      log_info "Found #{total_tracks} tracks to process for connection ##{@connection.id}."

      processed_count = 0
      total_edges_synced = 0

      track_ids.each_slice(BATCH_SIZE) do |batch|
        cache_nodes_metadata(batch)

        batch.each do |item_id|
          neighbors = begin
            client.similar_tracks_for(item_id, limit: SIMILAR_LIMIT)
          rescue StandardError => error
            log_info "Could not fetch similar tracks for track ##{item_id}: #{error.message}. Skipping."
            []
          end

          edges_count = upsert_edges(item_id, neighbors)
          total_edges_synced += edges_count
          processed_count += 1
        end

        log_info "Processed #{processed_count}/#{total_tracks} tracks (#{total_edges_synced} similarity edges synced so far)..."
      end

      log_info "Completed sonic graph build for connection ##{@connection.id} (#{@connection.name}): #{processed_count} tracks processed, #{total_edges_synced} similarity edges total."
    end

    private

    def client
      @client ||= Integrations::Client.for(@connection)
    end

    def cache_nodes_metadata(batch_item_ids)
      tracks = client.recommendation_tracks_by_ids(batch_item_ids)
      now = Time.current

      records = tracks.map do |item|
        {
          server_connection_id: @connection.id,
          item_id: item["Id"].to_s,
          title: item["Name"].presence || "Untitled",
          artist: item["AlbumArtist"] || item["Artists"]&.join(", ") || "Unknown artist",
          artwork_url: "/server_connections/#{@connection.id}/artwork/#{item['Id']}",
          synced_at: now,
          created_at: now,
          updated_at: now
        }
      end

      return if records.empty?

      SonicGraphNode.upsert_all(
        records,
        unique_by: :idx_sonic_graph_nodes_unique,
        update_only: [ :title, :artist, :artwork_url, :synced_at, :updated_at ]
      )
    rescue StandardError => error
      log_info "Could not cache node metadata: #{error.message}"
    end

    def upsert_edges(from_item_id, neighbors)
      now = Time.current
      records = neighbors.map do |neighbor|
        {
          server_connection_id: @connection.id,
          from_item_id: from_item_id.to_s,
          to_item_id: neighbor[:id].to_s,
          distance: neighbor[:distance],
          synced_at: now,
          created_at: now,
          updated_at: now
        }
      end
      return 0 if records.empty?

      TrackSimilarity.upsert_all(
        records,
        unique_by: :idx_track_similarities_unique,
        update_only: [ :distance, :synced_at, :updated_at ]
      )
      records.size
    end

    def log_info(message)
      @logger&.info("[SonicGraph] #{message}")
    end
  end
end
