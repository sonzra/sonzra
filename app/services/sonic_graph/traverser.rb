module SonicGraph
  class Traverser
    def initialize(connection)
      @connection = connection
    end

    def next_tracks(current_item_id, limit: 5, history_item_ids: [])
      history_set = Set.new(history_item_ids.map(&:to_s) + [ current_item_id.to_s ])

      neighbors = TrackSimilarity.neighbors_for(@connection, current_item_id, limit: limit * 3)
        .reject { |edge| history_set.include?(edge.to_item_id) }
        .first(limit)

      neighbors.map(&:to_item_id)
    end

    def graph_available?(item_id)
      TrackSimilarity.where(server_connection: @connection, from_item_id: item_id.to_s).exists?
    end
  end
end
