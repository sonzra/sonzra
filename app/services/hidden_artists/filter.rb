require "set"

module HiddenArtists
  class Filter
    def initialize(user, server_connection)
      @hidden_artist_ids = user.hidden_artists.where(server_connection:).pluck(:artist_id).to_set
    end

    def items(items)
      items.reject { |item| hidden?(item) }
    end

    def hidden?(item)
      artist_ids(item).any? { |artist_id| @hidden_artist_ids.include?(artist_id) }
    end

    def artist_ids(item)
      [ item["Type"] == "MusicArtist" ? item["Id"] : nil,
        item.dig("AlbumArtists", 0, "Id"),
        *Array(item["ArtistItems"]).pluck("Id"),
        *Array(item["Artists"]).filter_map { |artist| artist["Id"] if artist.is_a?(Hash) } ].compact
    end
  end
end
