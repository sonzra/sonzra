module SonicGraph
  class TrackCatalog
    CACHE_TTL = 6.hours

    def initialize(server_connection:, client:)
      @server_connection = server_connection
      @client = client
    end

    def track_ids
      cached_track_ids || refresh_track_ids
    end

    private

    attr_reader :server_connection, :client

    def cached_track_ids
      Rails.cache.read(cache_key)
    end

    def refresh_track_ids
      track_ids = client.all_track_ids.map(&:to_s)
      return [] if track_ids.empty?

      Rails.cache.write(cache_key, track_ids, expires_in: CACHE_TTL)
      track_ids
    end

    def cache_key
      [ "sonic_graph", "track_catalog", server_connection.id ]
    end
  end
end
