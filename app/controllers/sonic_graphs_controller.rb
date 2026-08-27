class SonicGraphsController < ApplicationController
  rescue_from Integrations::Jellyfin::Client::AuthenticationError, Integrations::Plex::Client::AuthenticationError do
    redirect_to server_connections_path, alert: "Your server session expired. Please re-authenticate your server connection."
  end

  def index
    server_connection = current_user.preferred_server_connection || current_user.server_connections.first
    return redirect_to root_path unless server_connection

    cached_nodes = SonicGraphNode.where(server_connection:)

    # Count connections per track ID to determine node size (degree centrality)
    degrees = TrackSimilarity.where(server_connection:).group(:from_item_id).count

    @nodes = cached_nodes.map do |node|
      deg = degrees[node.item_id] || 0
      {
        id: node.item_id,
        label: node.title,
        group: node.artist.presence || "Unknown artist",
        image: node.artwork_url,
        audio_url: audio_server_connection_path(server_connection, node.item_id),
        graph_url: sonic_graph_server_connection_path(server_connection, node.item_id),
        degree: deg
      }
    end

    node_ids = @nodes.map { |n| n[:id] }
    all_edges = TrackSimilarity.where(server_connection:, from_item_id: node_ids, to_item_id: node_ids)
    @edges = all_edges.pluck(:from_item_id, :to_item_id, :distance).map do |from, to, dist|
      { from:, to:, value: (1.0 - (dist || 1.0)).round(2) }
    end

    respond_to do |format|
      format.html
      format.json { render json: { nodes: @nodes, edges: @edges } }
    end
  end

  def show
    server_connection = current_user.server_connections.find(params.expect(:server_connection_id))
    client = Integrations::Client.for(server_connection, remote_user_id: session.dig(:server_remote_user_ids, server_connection.id.to_s))

    item_id = params.expect(:item_id)
    center_items = client.recommendation_tracks_by_ids([ item_id ])
    @center_item = center_items.first

    traverser = SonicGraph::Traverser.new(server_connection)
    neighbor_ids = traverser.next_tracks(item_id, limit: 10)
    neighbor_tracks = neighbor_ids.present? ? client.recommendation_tracks_by_ids(neighbor_ids) : []

    # Map distance scores from local graph
    edges = TrackSimilarity.where(server_connection:, from_item_id: item_id, to_item_id: neighbor_ids).index_by(&:to_item_id)

    @neighbors = neighbor_tracks.map do |item|
      edge = edges[item["Id"]]
      {
        item_id: item["Id"],
        title: item["Name"],
        artist: item["AlbumArtist"] || item["Artists"]&.join(", ") || "Unknown artist",
        artwork: helpers.library_artwork_path(server_connection, item) || "/brand/sonzra-mark.svg",
        audio_url: audio_server_connection_path(server_connection, item["Id"]),
        radio_url: radio_tracks_server_connection_path(server_connection, item["Id"]),
        graph_url: sonic_graph_server_connection_path(server_connection, item["Id"]),
        distance: edge&.distance || 1.0
      }
    end

    respond_to do |format|
      format.html
      format.json do
        render json: {
          center: @center_item ? {
            item_id: @center_item["Id"],
            title: @center_item["Name"],
            artist: @center_item["AlbumArtist"] || @center_item["Artists"]&.join(", ") || "Unknown artist",
            artwork: helpers.library_artwork_path(server_connection, @center_item) || "/brand/sonzra-mark.svg",
            audio_url: audio_server_connection_path(server_connection, @center_item["Id"])
          } : nil,
          neighbors: @neighbors
        }
      end
    end
  end
end
