require "set"

module HiddenGenres
  class Filter
    attr_reader :hidden_genre_names

    def initialize(user, server_connection)
      @hidden_genre_names = if user && server_connection
        user.hidden_genres.where(server_connection:).pluck(:name).map { |n| n.strip.downcase }.to_set
      else
        Set.new
      end
    end

    def items(items)
      return items if @hidden_genre_names.empty?

      items.reject { |item| hidden?(item) }
    end

    def hidden?(item)
      return false if @hidden_genre_names.empty?

      genre_names(item).any? { |genre| @hidden_genre_names.include?(genre.downcase) }
    end

    def genre_names(item)
      if item.is_a?(String)
        [ item ]
      elsif item.respond_to?(:genre)
        Array(item.genre).compact
      elsif item.is_a?(Hash)
        if item["Type"].in?([ "MusicGenre", "Genre" ])
          Array(item["Name"]).compact
        else
          (Array(item["Genres"]) + Array(item["GenreItems"]).pluck("Name")).compact
        end
      else
        []
      end
    end
  end
end
