class SonicGraphsController < ApplicationController
  ARTIST_CONNECTION_LIMIT = 4
  ARTIST_DISTANCE_LIMIT = 0.45
  ARTIST_EDGE_SAMPLE_SIZE = 3
  ARTIST_MINIMUM_EVIDENCE = 2

  rescue_from Integrations::Jellyfin::Client::AuthenticationError, Integrations::Plex::Client::AuthenticationError do
    redirect_to server_connections_path, alert: "Your server session expired. Please re-authenticate your server connection."
  end

  rescue_from Integrations::Jellyfin::Client::ConnectionError, Integrations::Plex::Client::ConnectionError do |error|
    respond_to do |format|
      format.html { redirect_to server_connections_path, alert: "Could not connect to media server: #{error.message}" }
      format.json { render json: { error: error.message }, status: :bad_gateway }
    end
  end

  def index
    server_connection = current_user.preferred_server_connection || current_user.server_connections.first
    return redirect_to root_path unless server_connection

    last_nodes_updated = SonicGraphNode.where(server_connection:).current_analysis.maximum(:updated_at)
    last_edges_updated = TrackSimilarity.where(server_connection:, analysis_version: SonicGraphNode::CURRENT_ANALYSIS_VERSION).maximum(:updated_at)

    cached_payload = Rails.cache.fetch([ "sonic_graph_v5", server_connection.id, last_nodes_updated, last_edges_updated ]) { artist_payload(server_connection) }

    @nodes = cached_payload[:nodes]
    @edges = cached_payload[:edges]

    respond_to do |format|
      format.html
      format.json { render json: cached_payload }
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

  private

  def artist_payload(server_connection)
    artists = SonicGraphNode.where(server_connection:).current_analysis.group_by { |node| node.artist.presence || "Unknown artist" }
    nodes = artists.map do |artist_name, tracks|
      representative = tracks.find(&:artwork_url?) || tracks.first
      {
        id: artist_name,
        label: artist_name,
        image: representative&.artwork_url || "/brand/sonzra-mark.svg",
        track_count: tracks.size
      }
    end.sort_by { |node| [ -node[:track_count], node[:label].downcase ] }

    connection_count = Hash.new(0)
    edges = aggregate_artist_edges(server_connection).each_with_object([]) do |edge, accepted|
      next if connection_count[edge[:from]] >= ARTIST_CONNECTION_LIMIT
      next if connection_count[edge[:to]] >= ARTIST_CONNECTION_LIMIT

      accepted << edge
      connection_count[edge[:from]] += 1
      connection_count[edge[:to]] += 1
    end

    { nodes:, edges: }
  end

  def aggregate_artist_edges(server_connection)
    query = <<~SQL.squish
      WITH artist_pair_distances AS (
        SELECT
          CASE WHEN n1.artist < n2.artist THEN n1.artist ELSE n2.artist END AS from_artist,
          CASE WHEN n1.artist < n2.artist THEN n2.artist ELSE n1.artist END AS to_artist,
          CASE WHEN n1.artist < n2.artist THEN n1.item_id ELSE n2.item_id END AS from_track_id,
          CASE WHEN n1.artist < n2.artist THEN n2.item_id ELSE n1.item_id END AS to_track_id,
          similarities.distance AS distance
        FROM track_similarities similarities
        INNER JOIN sonic_graph_nodes n1
          ON n1.item_id = similarities.from_item_id
          AND n1.server_connection_id = similarities.server_connection_id
        INNER JOIN sonic_graph_nodes n2
          ON n2.item_id = similarities.to_item_id
          AND n2.server_connection_id = similarities.server_connection_id
        WHERE similarities.server_connection_id = :connection_id
          AND similarities.analysis_version = :analysis_version
          AND n1.analysis_version = :analysis_version
          AND n2.analysis_version = :analysis_version
          AND n1.artist IS NOT NULL
          AND n2.artist IS NOT NULL
          AND n1.artist != n2.artist
          AND similarities.distance <= :distance_limit
      ), unique_track_pairs AS (
        SELECT from_artist, to_artist, from_track_id, to_track_id, MIN(distance) AS distance
        FROM artist_pair_distances
        GROUP BY from_artist, to_artist, from_track_id, to_track_id
      ), ranked_distances AS (
        SELECT *, ROW_NUMBER() OVER (
          PARTITION BY from_artist, to_artist
          ORDER BY distance ASC
        ) AS position
        FROM unique_track_pairs
      )
      SELECT from_artist, to_artist, AVG(distance) AS distance, COUNT(*) AS evidence
      FROM ranked_distances
      WHERE position <= :sample_size
      GROUP BY from_artist, to_artist
      HAVING COUNT(*) >= :minimum_evidence
        AND COUNT(DISTINCT from_track_id) >= :minimum_evidence
        AND COUNT(DISTINCT to_track_id) >= :minimum_evidence
      ORDER BY distance ASC, evidence DESC
    SQL
    sanitised_query = ApplicationRecord.sanitize_sql_array([
      query,
      { connection_id: server_connection.id, analysis_version: SonicGraphNode::CURRENT_ANALYSIS_VERSION, distance_limit: ARTIST_DISTANCE_LIMIT, sample_size: ARTIST_EDGE_SAMPLE_SIZE, minimum_evidence: ARTIST_MINIMUM_EVIDENCE }
    ])

    ApplicationRecord.connection.select_all(sanitised_query).map do |edge|
      {
        from: edge.fetch("from_artist"),
        to: edge.fetch("to_artist"),
        distance: edge.fetch("distance").to_f.round(4),
        evidence: edge.fetch("evidence").to_i
      }
    end
  end
end
