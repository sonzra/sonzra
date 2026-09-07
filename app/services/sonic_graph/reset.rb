module SonicGraph
  class Reset
    def initialize(connection)
      @connection = connection
    end

    def call
      edges_deleted = delete_in_batches(TrackSimilarity.where(server_connection: connection))
      nodes_deleted = delete_in_batches(SonicGraphNode.where(server_connection: connection))

      ResetResultData.new(nodes_deleted:, edges_deleted:)
    end

    private

    attr_reader :connection

    def delete_in_batches(relation)
      relation.in_batches(of: 100_000).sum(&:delete_all)
    end
  end
end
