require "json"
require "net/http"
require "uri"
require_relative "../capabilities"
require_relative "../capability_support"

module Integrations
  module Plex
    class Client
      CAPABILITIES = [ Integrations::Capabilities::SONIC_GRAPH ].freeze
      include Integrations::CapabilitySupport

      AuthenticationError = Integrations::Jellyfin::Client::AuthenticationError
      ConnectionError = Integrations::Jellyfin::Client::ConnectionError

      PLEX_CLOUD_URL = "https://plex.tv".freeze
      LONGFORM_LIBRARY_NAMES = { audiobook: "audiobooks", podcast: "podcasts" }.freeze

      def initialize(base_url:, access_token: nil, http: Net::HTTP, **)
        @base_url = normalize_base_url(base_url)
        @access_token = access_token
        @http = http
        @client_identifier = ENV.fetch("PLEX_CLIENT_ID") do
          raise ConnectionError, "PLEX_CLIENT_ID must be configured before adding a Plex connection."
        end
      end

      def initiate_pin(forward_url:)
        response = request(:post, "#{PLEX_CLOUD_URL}/api/v2/pins", params: { strong: true }, form: true)
        pin = parse_json(response)
        { "id" => pin.fetch("id").to_s, "code" => pin.fetch("code"), "url" => authorization_url(pin.fetch("code"), forward_url) }
      end

      def pin_status(pin_id:, code:)
        response = request(:get, "#{PLEX_CLOUD_URL}/api/v2/pins/#{pin_id}", params: { code: })
        parse_json(response)["authToken"]
      end

      def authenticate
        raise AuthenticationError if @access_token.blank?

        identity = server_identity
        identity["myPlexUsername"].presence || identity["friendlyName"].presence || "Plex account"
      end

      def authenticated_account_name(access_token:)
        @access_token = access_token
        authenticate
      end

      def home_content
        section = music_section
        audiobooks = longform_items(:audiobook, sort: "addedAt:desc", limit: 8)
        podcasts = longform_items(:podcast, sort: "addedAt:desc", limit: 8)
        content = {
          user_name: authenticate,
          recently_played: section_items(section, type: 10, sort: "lastViewedAt:desc", limit: 8),
          recently_added_albums: section_items(section, type: 9, sort: "addedAt:desc", limit: 8),
          recently_added_artists: section_items(section, type: 8, sort: "addedAt:desc", limit: 8),
          genres: genres(section).first(8),
          most_played_songs: section_items(section, type: 10, sort: "viewCount:desc", limit: 8),
          most_played_albums: section_items(section, type: 9, sort: "viewCount:desc", limit: 8),
          continue_audiobooks: longform_items(:audiobook, sort: "lastViewedAt:desc", limit: 48).select { |item| playback_position(item).positive? }.first(8),
          continue_podcasts: longform_items(:podcast, sort: "lastViewedAt:desc", limit: 48).select { |item| playback_position(item).positive? }.first(8),
          recently_added_audiobooks: audiobooks,
          recently_added_podcasts: podcasts
        }
        Integrations::Jellyfin::HomeContentResponseData.new(content:, access_token: @access_token)
      end

      def library_collection(collection, page:, query:, genre: nil, letter: nil)
        if collection == :playlists
          items = playlists
          return collection_response(items, page:, total: items.size)
        end

        if collection.in?([ :audiobooks, :podcasts ])
          kind = collection.to_s.singularize.to_sym
          section = longform_section(kind)
          return collection_response([], page:, total: 0) unless section

          response = section_response(section, type: 10, sort: "titleSort", page:, query:, genre:)
          return collection_response(response.fetch("Metadata", []).map { |item| normalize_item(item, kind:) }, page:, total: response.fetch("totalSize", 0))
        end

        section = music_section
        type, sort = case collection
        when :artists then [ 8, "titleSort" ]
        when :albums, :recently_added_albums then [ 9, collection == :recently_added_albums ? "addedAt:desc" : "titleSort" ]
        when :recently_played then [ 10, "lastViewedAt:desc" ]
        when :most_played_songs then [ 10, "viewCount:desc" ]
        when :genres
          items = genres(section)
          return collection_response(items, page:, total: items.size)
        else raise ArgumentError, "Unsupported collection: #{collection}"
        end
        response = section_response(section, type:, sort:, page:, query:, genre:)
        collection_response(response.fetch("Metadata", []).map { |item| normalize_item(item) }, page:, total: response.fetch("totalSize", 0))
      end

      def library_item_details(item_id)
        item = item_metadata(item_id)
        normalized_item = normalize_item(item)
        kind = longform_kind(item)
        if kind
          normalized_item = normalize_item(item, kind:)
          details = { item: normalized_item, album: normalized_item, kind:, chapters: [], tracks: [], other_albums: [], similar_albums: [] }
          return Integrations::Jellyfin::LibraryItemDetailsResponseData.new(details:, access_token: @access_token)
        end

        case normalized_item["Type"]
        when "MusicArtist"
          albums = artist_albums(item_id)
          details = { item: normalized_item, album: normalized_item, tracks: [], other_albums: albums, similar_albums: [] }
        when "MusicAlbum"
          details = { item: normalized_item, album: normalized_item, tracks: children(item_id, type: 10), other_albums: [], similar_albums: [] }
        when "Audio"
          album = metadata(item.fetch("parentRatingKey"))
          details = { item: normalized_item, album: normalize_item(album), tracks: children(album.fetch("ratingKey"), type: 10), other_albums: [], similar_albums: [] }
        when "Playlist"
          details = { item: normalized_item, album: normalized_item, tracks: playlist_items(item_id), other_albums: [], similar_albums: [], kind: :playlist }
        else
          details = { item: normalized_item, album: normalized_item, tracks: [], other_albums: [], similar_albums: [] }
        end
        Integrations::Jellyfin::LibraryItemDetailsResponseData.new(details:, access_token: @access_token)
      end

      def playback_queue(item_id)
        item = item_metadata(item_id)
        items = case item["type"]
        when "artist" then artist_albums(item_id).flat_map { |album| children(album.fetch("Id"), type: 10) }
        when "album" then children(item_id, type: 10)
        when "playlist" then playlist_items(item_id)
        else [ normalize_item(item) ]
        end
        Integrations::Jellyfin::PlaybackQueueResponseData.new(items:, access_token: @access_token)
      end

      def instant_mix(item_id, limit: 12)
        seed = metadata(item_id)
        items = sonically_similar_tracks(item_id, limit)
        items = genre_radio_tracks(seed, limit) if items.empty?
        items = library_radio_tracks(seed, limit) if items.empty?
        items = items.reject { |item| item["Id"] == item_id.to_s || item.dig("AlbumArtists", 0, "Id") == seed["grandparentRatingKey"].to_s }.first(limit)
        Integrations::Jellyfin::PlaybackQueueResponseData.new(items:, access_token: @access_token)
      end

      def recommendation_tracks(strategy, period_date)
        section = music_section
        case strategy
        when "friday_rediscovery"
          tracks = recommendation_tracks_for(section, sort: "random", limit: 200)
            .select { |track| track.dig("UserData", "LastPlayedDate").blank? || Time.zone.parse(track.dig("UserData", "LastPlayedDate")) < period_date - 14.days }
          tracks.empty? ? recommendation_tracks_for(section, sort: "random", limit: 200) : tracks
        when "best_of_genre"
          popular = recommendation_tracks_for(section, sort: "viewCount:desc", limit: 100)
          genre = popular.flat_map { |track| track["Genres"] }.tally.max_by { |_, count| count }&.first
          genre ? recommendation_tracks_for(section, sort: "viewCount:desc", genre:, limit: 200) : recommendation_tracks_for(section, sort: "random", limit: 200)
        when "more_from_artist"
          recent = recommendation_tracks_for(section, sort: "lastViewedAt:desc", limit: 100)
          artist_id = recent.group_by { |track| track.dig("AlbumArtists", 0, "Id") }.max_by { |_, tracks| tracks.size }&.first
          artist_id ||= recommendation_tracks_for(section, sort: "viewCount:desc", limit: 50).first&.dig("AlbumArtists", 0, "Id")
          artist_id ? recommendation_tracks_for(section, sort: "random", artist_id:, limit: 200) : []
        when "all_time_top"
          recommendation_tracks_for(section, sort: "viewCount:desc", limit: 200)
        else
          []
        end
      end

      def monthly_top_tracks(_period_date)
        recommendation_tracks_for(music_section, sort: "viewCount:desc", limit: 20)
      end

      def recommendation_tracks_by_ids(item_ids)
        item_ids.filter_map { |item_id| normalize_item(metadata(item_id)) }
      end

      def all_track_ids
        section = music_section
        media_items("/library/sections/#{section.fetch("key")}/all", type: 10, "X-Plex-Container-Size" => 10_000)
          .map { |item| item["Id"] }
      rescue ConnectionError
        []
      end

      def similar_tracks_for(item_id, limit: 20)
        media_items("/library/metadata/#{item_id}/nearest", limit:)
          .map { |item| { id: item["Id"], distance: 1.0 } }
      rescue ConnectionError
        []
      end

      def lyrics(item_id)
        stream = lyric_stream(metadata(item_id))
        return Integrations::Jellyfin::LyricsResponseData.new(lines: [], access_token: @access_token, available: false) unless stream

        response = request(:get, "#{@base_url}#{stream.fetch("key")}", allow_not_found: true)
        return Integrations::Jellyfin::LyricsResponseData.new(lines: [], access_token: @access_token, available: false) if response.code == "404"

        Integrations::Jellyfin::LyricsResponseData.new(lines: parsed_lyrics(response.body), access_token: @access_token, available: true)
      end

      def playlists
        media_items("/playlists", playlistType: "audio")
      end

      def create_playlist(name, item_ids:)
        ids = Array(item_ids).compact_blank
        raise ConnectionError, "Plex requires at least one track when creating a playlist." if ids.empty?

        response = request(:post, "#{@base_url}/playlists", params: { type: "audio", title: name, smart: 0, uri: playlist_uri(ids) })
        created_playlist_id(response, name) || raise(ConnectionError, "Plex created the playlist but did not return its ID.")
      end

      def add_to_playlist(playlist_id:, item_ids: nil, item_id: nil)
        ids = Array(item_ids || item_id)
        return if ids.empty?

        request(:put, "#{@base_url}/playlists/#{playlist_id}/items", params: { uri: playlist_uri(ids) })
      end

      def delete_playlist(playlist_id:)
        request(:delete, "#{@base_url}/playlists/#{playlist_id}")
      end

      def remove_from_playlist(playlist_id:, entry_id:)
        request(:delete, "#{@base_url}/playlists/#{playlist_id}/items/#{entry_id}")
      end

      def artwork(item_id:, tag: nil, access_token: nil)
        @access_token = access_token if access_token.present?
        item = metadata(item_id)
        thumbnail_path = item["thumb"] || item["parentThumb"] || item["grandparentThumb"]
        raise ConnectionError, "Plex could not find artwork for this item." if thumbnail_path.blank?

        response = request(:get, "#{@base_url}#{thumbnail_path}")
        Integrations::Jellyfin::ArtworkResponseData.new(body: response.body, content_type: response["Content-Type"] || "image/jpeg")
      end

      def stream_audio(item_id:, range:, access_token: nil)
        @access_token = access_token if access_token.present?
        part_key = metadata(item_id).dig("Media", 0, "Part", 0, "key")
        raise ConnectionError, "Plex could not find an audio file for this track." if part_key.blank?

        uri = URI.parse("#{@base_url}#{part_key}")
        headers = self.headers(nil)
        headers["Range"] = range if range.present?
        @http.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 5, read_timeout: 10) do |connection|
          connection.request(Net::HTTP::Get.new(uri, headers)) do |response|
            raise AuthenticationError if response.code == "401"
            raise ConnectionError, "Plex returned HTTP #{response.code}." unless response.is_a?(Net::HTTPSuccess) || response.code == "206"

            yield Integrations::Jellyfin::AudioStreamResponseData.new(
              body: nil,
              accept_ranges: response["Accept-Ranges"],
              content_type: response["Content-Type"] || "audio/mpeg",
              content_length: response["Content-Length"],
              content_range: response["Content-Range"],
              status: response.code.to_i
            )
            response.read_body { |chunk| yield chunk }
          end
        end
      rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNREFUSED
        raise ConnectionError, "Could not reach Plex. Check the address and try again."
      end

      def report_playback(event:, item_id:, position_ticks:, paused:, duration_ticks: 0, access_token: nil)
        @access_token = access_token if access_token.present?
        duration_ticks = metadata(item_id).fetch("duration", 0).to_i * 10_000 if duration_ticks.to_i.zero?
        playback_reporter.report(event:, item_id:, position_ticks:, paused:, duration_ticks:)
        Integrations::Jellyfin::PlaybackReportResponseData.new(access_token: @access_token)
      end

      def update_playback_position(item_id:, position_ticks:, access_token: nil)
        @access_token = access_token if access_token.present?
        playback_reporter.reset(item_id) if position_ticks.to_i.zero?
        Integrations::Jellyfin::PlaybackReportResponseData.new(access_token: @access_token)
      end

      def update_favorite(item_id:, favorite:)
        request(
          :get,
          "#{@base_url}/:/rate",
          params: { key: item_id, identifier: "com.plexapp.plugins.library", rating: favorite ? 10 : 0 }
        )
      end

      private

      def authorization_url(code, forward_url)
        query = URI.encode_www_form(
          clientID: @client_identifier,
          code:,
          forwardUrl: forward_url,
          "context[device][product]" => "Sonzra"
        )
        "https://app.plex.tv/auth#?#{query}"
      end

      def playback_reporter
        PlaybackReporter.new(base_url: @base_url, request: method(:request), access_token: @access_token)
      end

      def server_identity
        response = request(:get, "#{@base_url}/")
        payload = parse_json(response)
        payload.fetch("MediaContainer", payload)
      end

      def music_section
        @music_section ||= sections.find { |section| section["type"] == "artist" && longform_kind(section).nil? }
        raise ConnectionError, "Plex does not have a music library available to this account." unless @music_section

        @music_section
      end

      def sections
        @sections ||= media_container("/library/sections").fetch("Directory", [])
      end

      def section_items(section, type:, sort:, limit:)
        section_response(section, type:, sort:, page: 1, limit:).fetch("Metadata", []).map { |item| normalize_item(item) }
      end

      def longform_items(kind, sort:, limit:)
        section = longform_section(kind)
        return [] unless section

        section_response(section, type: 10, sort:, page: 1, limit:).fetch("Metadata", []).map { |item| normalize_item(item, kind:) }
      end

      def longform_section(kind)
        sections.find { |section| longform_kind(section) == kind }
      end

      def longform_kind(item)
        title = item["librarySectionTitle"].presence || (item["title"] if item["key"].present? && item["ratingKey"].blank?)
        title = sections.find { |section| section["key"].to_s == item["librarySectionID"].to_s }&.fetch("title") if title.blank? && item["librarySectionID"].present?
        title = title.to_s.downcase
        LONGFORM_LIBRARY_NAMES.key(title)
      end

      def playback_position(item)
        item.dig("UserData", "PlaybackPositionTicks").to_i
      end

      def section_response(section, type:, sort:, page:, query: nil, genre: nil, limit: Library::Pagination::PAGE_SIZE)
        parameters = {
          type:,
          sort:,
          "X-Plex-Container-Start" => (page - 1) * limit,
          "X-Plex-Container-Size" => limit,
          title: query.presence,
          genre: genre.presence
        }.compact
        media_container("/library/sections/#{section.fetch("key")}/all", parameters)
      end

      def recommendation_tracks_for(section, sort:, limit:, genre: nil, artist_id: nil)
        parameters = { type: 10, sort:, genre:, "artist.id" => artist_id, "X-Plex-Container-Size" => limit }.compact
        media_items("/library/sections/#{section.fetch("key")}/all", parameters)
      end

      def collection_response(items, page:, total:)
        Integrations::Jellyfin::LibraryCollectionResponseData.new(content: items, total:, access_token: @access_token)
      end

      def metadata(item_id)
        media_container("/library/metadata/#{item_id}").fetch("Metadata", []).first || raise(ConnectionError, "Plex could not find this item.")
      end

      def item_metadata(item_id)
        metadata(item_id)
      rescue ConnectionError => library_error
        playlist = media_container("/playlists/#{item_id}").fetch("Metadata", []).first
        playlist || raise(library_error)
      end

      def children(item_id, type: nil)
        parameters = { type:, "X-Plex-Container-Size" => 1_000 }.compact
        media_items("/library/metadata/#{item_id}/children", parameters)
      end

      def artist_albums(item_id)
        media_items("/library/metadata/#{item_id}/children", type: 9, "X-Plex-Container-Size" => 1_000)
      end

      def lyric_stream(item)
        media = Array(item["Media"])
        streams = media.flat_map { |entry| Array(entry["Stream"]) + Array(entry["Part"]).flat_map { |part| Array(part["Stream"]) } }
        streams.find { |stream| stream["streamType"].to_s == "4" }
      end

      def parsed_lyrics(body)
        payload = JSON.parse(body)
        lines = lyric_lines(payload)
        return LyricsParser.call(body) if lines.empty?

        lines.filter_map do |line|
          text = Array(line["Span"]).pluck("text").join.strip
          next if text.blank?

          { "Text" => text, "Start" => line["startOffset"].to_f * 10_000 }.compact
        end
      rescue JSON::ParserError
        LyricsParser.call(body)
      end

      def lyric_lines(value)
        case value
        when Hash
          return [ value ] if value.key?("Span") && value.key?("startOffset")

          value.values.flat_map { |child| lyric_lines(child) }
        when Array
          value.flat_map { |child| lyric_lines(child) }
        else
          []
        end
      end

      def sonically_similar_tracks(item_id, limit)
        media_items("/library/metadata/#{item_id}/nearest", limit:)
      rescue ConnectionError
        []
      end

      def genre_radio_tracks(seed, limit)
        genre = Array(seed["Genre"]).pluck("tag").first
        return [] if genre.blank?

        section_id = seed["librarySectionID"] || music_section.fetch("key")
        tracks = media_items(
          "/library/sections/#{section_id}/all",
          type: 10,
          sort: "random",
          genre:,
          "X-Plex-Container-Size" => limit * 4
        )
        diverse_tracks(tracks, seed, limit)
      end

      def library_radio_tracks(seed, limit)
        section_id = seed["librarySectionID"] || music_section.fetch("key")
        tracks = media_items(
          "/library/sections/#{section_id}/all",
          type: 10,
          sort: "random",
          "X-Plex-Container-Size" => limit * 4
        )
        diverse_tracks(tracks, seed, limit)
      end

      def diverse_tracks(tracks, seed, limit)
        seed_artist_id = seed["grandparentRatingKey"].to_s
        tracks.reject { |track| track.dig("AlbumArtists", 0, "Id") == seed_artist_id }.first(limit)
      end

      def genres(section)
        media_container("/library/sections/#{section.fetch("key")}/genre").fetch("Directory", []).map do |genre|
          { "Id" => "genre-#{genre["key"] || genre["title"]}", "Name" => genre["title"], "Type" => "MusicGenre" }
        end
      end

      def media_items(path, parameters = {})
        media_container(path, parameters).fetch("Metadata", []).map { |item| normalize_item(item) }
      end

      def playlist_items(playlist_id)
        media_container("/playlists/#{playlist_id}/items", "X-Plex-Container-Size" => 1_000).fetch("Metadata", []).map do |item|
          normalize_item(item).merge("PlaylistItemId" => (item["playlistItemID"] || item["ratingKey"]).to_s)
        end
      end

      def playlist_uri(item_ids)
        identity = server_identity
        "server://#{identity.fetch("machineIdentifier")}/com.plexapp.plugins.library/library/metadata/#{item_ids.join(",")}"
      end

      def media_container(path, parameters = {})
        parse_json(request(:get, "#{@base_url}#{path}", params: parameters)).fetch("MediaContainer", {})
      end

      def normalize_item(item, kind: nil)
        type = { "artist" => "MusicArtist", "album" => "MusicAlbum", "track" => "Audio", "playlist" => "Playlist" }.fetch(item["type"], item["type"].to_s.capitalize)
        type = "AudioBook" if kind == :audiobook && type == "Audio"
        artist_name = item["grandparentTitle"] || item["parentTitle"]
        artist_id = item["grandparentRatingKey"] || (type == "MusicAlbum" ? item["parentRatingKey"] : nil)
        album_id = item["parentRatingKey"] if type == "Audio"
        artwork = item["thumb"].presence || item["parentThumb"].presence || item["grandparentThumb"].presence
        artwork_item_id = artwork.to_s[%r{/library/metadata/(\d+)/thumb}, 1]
        item_id = item["ratingKey"].to_s
        {
          "Id" => item_id,
          "Name" => item["title"],
          "Type" => type,
          "Album" => type == "Audio" ? item["parentTitle"] : nil,
          "AlbumId" => (album_id || (type == "Audio" ? artwork_item_id : nil))&.to_s,
          "AlbumArtist" => artist_name,
          "AlbumArtists" => artist_id ? [ { "Id" => artist_id.to_s, "Name" => artist_name } ] : [],
          "ArtistItems" => artist_id ? [ { "Id" => artist_id.to_s, "Name" => artist_name } ] : [],
          "Artists" => artist_name ? [ artist_name ] : [],
          "Genres" => Array(item["Genre"]).pluck("tag"),
          "RunTimeTicks" => item["duration"].to_i * 10_000,
          "IndexNumber" => item["index"],
          "ProductionYear" => item["year"],
          "PremiereDate" => item["originallyAvailableAt"],
          "Overview" => item["summary"],
          "LibrarySectionId" => item["librarySectionID"]&.to_s,
          "ImageTags" => artwork_item_id == item_id ? { "Primary" => "plex" } : {},
          "AlbumPrimaryImageTag" => artwork_item_id && artwork_item_id != item_id ? "plex" : nil,
          "UserData" => { "IsFavorite" => item["userRating"].to_i.positive?, "PlayCount" => item["viewCount"].to_i, "LastPlayedDate" => item["lastViewedAt"] ? Time.zone.at(item["lastViewedAt"].to_i).iso8601 : nil, "PlaybackPositionTicks" => item["viewOffset"].to_i * 10_000 }.compact
        }.compact
      end

      def normalize_base_url(base_url)
        uri = URI.parse(base_url.to_s)
        uri.path = "" if uri.path.in?([ "/web", "/web/" ])
        uri.to_s.chomp("/")
      end

      def request(method, url, params: {}, access_token: nil, form: false, allow_not_found: false, max_retries: 2)
        uri = URI.parse(url)
        uri.query = URI.encode_www_form(params) if params.present? && !form
        request_class = { get: Net::HTTP::Get, post: Net::HTTP::Post, put: Net::HTTP::Put, delete: Net::HTTP::Delete }.fetch(method)
        request = request_class.new(uri, headers(access_token))
        if form
          request["Content-Type"] = "application/x-www-form-urlencoded"
          request.body = URI.encode_www_form(params)
        end
        retries = 0
        response = begin
          @http.start(uri.host, uri.port, use_ssl: uri.scheme == "https", open_timeout: 5, read_timeout: 10) { |connection| connection.request(request) }
        rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNREFUSED, Errno::ETIMEDOUT, Timeout::Error => error
          if retries < max_retries
            retries += 1
            sleep(0.5 * retries)
            retry
          end
          raise error
        end
        raise AuthenticationError if response.code == "401"
        raise ConnectionError, "Plex returned HTTP #{response.code}." unless response.is_a?(Net::HTTPSuccess) || (allow_not_found && response.code == "404")

        response
      rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNREFUSED, Errno::ETIMEDOUT, Timeout::Error
        raise ConnectionError, "Could not reach Plex. Check the address and try again."
      rescue OpenSSL::SSL::SSLError
        raise ConnectionError, "Could not establish a secure connection to Plex."
      rescue JSON::ParserError, KeyError
        raise ConnectionError, "Plex returned an unexpected response."
      end

      def headers(access_token)
        {
          "Accept" => "application/json",
          "X-Plex-Client-Identifier" => @client_identifier,
          "X-Plex-Product" => "Sonzra",
          "X-Plex-Platform" => "Web",
          "X-Plex-Token" => access_token.presence || @access_token.presence
        }.compact
      end

      def parse_json(response)
        JSON.parse(response.body)
      end

      def created_playlist_id(response, name)
        payload = parse_json(response)
        payload.dig("MediaContainer", "Metadata", 0, "ratingKey") || payload.dig("MediaContainer", "Metadata", 0, "key")&.to_s&.split("/")&.last
      rescue JSON::ParserError
        response["Location"].to_s[%r{/playlists/(\d+)}, 1] || playlists.find { |playlist| playlist["Name"] == name }&.fetch("Id")
      end
    end
  end
end
