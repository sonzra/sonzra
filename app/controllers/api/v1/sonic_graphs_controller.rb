module Api
  module V1
    class SonicGraphsController < ApplicationController
      allow_unauthenticated_access
      skip_before_action :verify_authenticity_token
      before_action :authenticate_analyzer_token!

      def status
        server_connection = ServerConnection.find_by(id: params[:server_connection_id]) || ServerConnection.first
        unless server_connection
          return render json: { status: "error", message: "No server connection found" }, status: :unprocessable_entity
        end

        all_ids = TrackSimilarity.where(server_connection:).distinct.pluck(:from_item_id)
        analyzed_ids = SonicGraphNode.where(server_connection:).pluck(:item_id)
        pending_ids = (all_ids - analyzed_ids).first(50)

        client = Integrations::Client.for(server_connection)
        pending_tracks = pending_ids.present? ? client.recommendation_tracks_by_ids(pending_ids) : []

        if pending_ids.present? && pending_tracks.empty?
          now = Time.current
          dummy_records = pending_ids.map do |id|
            {
              server_connection_id: server_connection.id,
              item_id: id.to_s,
              title: "Track #{id}",
              artist: "Unknown artist",
              artwork_url: "/server_connections/#{server_connection.id}/artwork/#{id}",
              synced_at: now,
              created_at: now,
              updated_at: now
            }
          end
          SonicGraphNode.upsert_all(dummy_records, unique_by: :idx_sonic_graph_nodes_unique)
          analyzed_ids = SonicGraphNode.where(server_connection:).pluck(:item_id)
          pending_ids = (all_ids - analyzed_ids).first(50)
        end

        render json: {
          status: "ok",
          server_connection_id: server_connection.id,
          total_indexed_tracks: all_ids.size,
          analyzed_nodes: analyzed_ids.size,
          pending_count: (all_ids.size - analyzed_ids.size),
          pending_tracks: pending_tracks.map { |t|
            {
              item_id: t["Id"],
              title: t["Name"],
              artist: t["AlbumArtist"] || t["Artists"]&.join(", ") || "Unknown artist",
              artwork_url: "/server_connections/#{server_connection.id}/artwork/#{t['Id']}",
              audio_url: "/server_connections/#{server_connection.id}/audio/#{t['Id']}"
            }
          }
        }
      end

      def resolve_paths
        server_connection = ServerConnection.find_by(id: params[:server_connection_id]) || ServerConnection.first
        file_paths = Array(params[:file_paths])

        resolved = {}
        file_paths.each do |path|
          filename = File.basename(path, ".*")
          similarity = TrackSimilarity.where(server_connection:)
                                       .joins("INNER JOIN sonic_graph_nodes ON sonic_graph_nodes.item_id = track_similarities.from_item_id")
                                       .where("sonic_graph_nodes.title LIKE ?", "%#{filename}%")
                                       .first

          if similarity
            resolved[path] = { server_connection_id: server_connection.id, item_id: similarity.from_item_id }
          end
        end

        render json: { status: "ok", resolved: }
      end

      def edges
        server_connection = ServerConnection.find_by(id: params[:server_connection_id]) || ServerConnection.first
        unless server_connection
          return render json: { status: "error", message: "Server connection not found" }, status: :not_found
        end

        nodes_data = Array(params[:nodes])
        edges_data = Array(params[:edges])

        now = Time.current

        if nodes_data.present?
          node_records = nodes_data.map do |n|
            {
              server_connection_id: server_connection.id,
              item_id: n[:item_id].to_s,
              title: n[:title].presence || "Untitled",
              artist: n[:artist] || "Unknown artist",
              artwork_url: n[:artwork_url] || "/server_connections/#{server_connection.id}/artwork/#{n[:item_id]}",
              synced_at: now,
              created_at: now,
              updated_at: now
            }
          end
          SonicGraphNode.upsert_all(node_records, unique_by: :idx_sonic_graph_nodes_unique)
        end

        if edges_data.present?
          edge_records = edges_data.map do |e|
            {
              server_connection_id: server_connection.id,
              from_item_id: e[:from_item_id].to_s,
              to_item_id: e[:to_item_id].to_s,
              distance: e[:distance].to_f.round(4),
              synced_at: now,
              created_at: now,
              updated_at: now
            }
          end
          TrackSimilarity.upsert_all(edge_records, unique_by: :idx_track_similarities_unique)
        end

        render json: {
          status: "success",
          nodes_upserted: nodes_data.size,
          edges_upserted: edges_data.size
        }
      end

      private

      def authenticate_analyzer_token!
        expected_token = ENV["ANALYZER_API_KEY"].presence || "development_analyzer_token"
        provided_token = request.headers["X-Sonzra-Analyzer-Token"]

        unless ActiveSupport::SecurityUtils.secure_compare(provided_token.to_s, expected_token)
          render json: { status: "error", message: "Unauthorized analyzer token" }, status: :unauthorized
        end
      end
    end
  end
end
