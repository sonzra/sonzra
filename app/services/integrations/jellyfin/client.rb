require "json"
require "net/http"
require "uri"

module Integrations
  module Jellyfin
    class Client
      class AuthenticationError < StandardError; end
      class ConnectionError < StandardError; end

      def initialize(base_url:, username: nil, password: nil, access_token: nil, remote_user_id: nil, http: Net::HTTP)
        @base_url = base_url
        @username = username
        @password = password
        @access_token = access_token
        @remote_user_id = remote_user_id
        @http = http
      end

      def authenticate
        authentication.fetch("User").fetch("Name")
      end

      def resolved_user_id
        @resolved_user&.dig("Id")
      end

      def home_content
        session = authentication
        user_id = session.fetch("User").fetch("Id")
        token = session.fetch("AccessToken")
        podcast_library = podcast_library(user_id, token)
        podcast_album_ids = podcast_library ? podcast_album_ids(user_id, token, podcast_library) : []
        recently_played = items(user_id, token, SortBy: "DatePlayed", IncludeItemTypes: "Audio")
        recently_played_podcast_ids = podcast_library ? podcast_items(user_id, token, podcast_library: podcast_library, Limit: 48, SortBy: "DatePlayed").fetch("Items", []).pluck("Id") : []
        recently_played_music = recently_played.reject { |item| recently_played_podcast_ids.include?(item["Id"]) }
        resumable_audiobooks = resume_items(user_id, token, IncludeItemTypes: "AudioBook")
        resumable_podcasts = podcast_library ? resume_items(user_id, token, IncludeItemTypes: "Audio", ParentId: podcast_library.fetch("Id")) : []
        recently_added_albums = music_albums_without_podcasts(items(user_id, token, SortBy: "DateCreated", IncludeItemTypes: "MusicAlbum"), podcast_library, podcast_album_ids)
        recently_added_artists = get("Artists", token, UserId: user_id, Limit: 8).fetch("Items", [])
        available_genres = get("MusicGenres", token, UserId: user_id, Limit: 8).fetch("Items", [])
        most_played_songs = music_songs_without_podcasts(played_items(items(user_id, token, limit: 48, SortBy: "PlayCount", EnableUserData: true, IncludeItemTypes: "Audio", Fields: "Genres")), podcast_album_ids)
        most_played_albums = music_albums_without_podcasts(played_items(items(user_id, token, limit: 48, SortBy: "PlayCount", EnableUserData: true, IncludeItemTypes: "MusicAlbum")), podcast_library, podcast_album_ids)
        recently_added_audiobooks = items(user_id, token, SortBy: "DateCreated", IncludeItemTypes: "AudioBook")
        recently_added_podcasts = podcast_library ? podcast_items(user_id, token, podcast_library: podcast_library, Limit: 8, SortBy: "DateCreated", SortOrder: "Descending").fetch("Items", []) : []

        content = {
          user_name: session.fetch("User").fetch("Name"),
          recently_played: recently_played_music,
          recently_added_albums: recently_added_albums,
          recently_added_artists: recently_added_artists,
          genres: personalized_genres(most_played_songs, recently_played_music).presence || available_genres,
          most_played_songs: most_played_songs,
          most_played_albums: most_played_albums,
          continue_audiobooks: resumable_audiobooks,
          continue_podcasts: resumable_podcasts,
          recently_added_audiobooks: recently_added_audiobooks,
          recently_added_podcasts: recently_added_podcasts
        }

        HomeContentResponseData.new(content: content, access_token: token)
      rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNREFUSED
        raise ConnectionError, "Could not reach the server. Check the address and try again."
      rescue OpenSSL::SSL::SSLError
        raise ConnectionError, "Could not establish a secure connection to the server."
      end

      def library_item_details(item_id)
        session = authentication
        user_id = session.fetch("User").fetch("Id")
        token = session.fetch("AccessToken")
        item = get("Users/#{user_id}/Items/#{item_id}", token, EnableUserData: true, Fields: "Overview,Genres,DateCreated,RunTimeTicks,AlbumArtists,People,ProductionYear,PremiereDate,Studios,SeriesName,IndexNumber")
        item["UserData"] = get("UserItems/#{item_id}/UserData", token, UserId: user_id)
        return playlist_details(item, user_id, token) if item["Type"] == "Playlist"
        podcast_library = podcast_library(user_id, token)
        podcast_album_ids = podcast_library ? podcast_album_ids(user_id, token, podcast_library) : []
        kind = media_kind(item, user_id, token, podcast_library)
        return non_music_item_details(item, token, kind) unless kind == :music

        artist = item["Type"] == "MusicArtist"
        album = item["Type"] == "Audio" && item["AlbumId"] ? get("Users/#{user_id}/Items/#{item["AlbumId"]}", token, Fields: "AlbumArtists,Overview") : item
        tracks = album["Type"] == "MusicAlbum" ? all_items(user_id, token, ParentId: album["Id"], IncludeItemTypes: "Audio", SortBy: "ParentIndexNumber,IndexNumber", sort_order: "Ascending") : []
        artist_id = artist ? item["Id"] : album.dig("AlbumArtists", 0, "Id") || item.dig("AlbumArtists", 0, "Id")
        other_albums = artist_id ? optional_items { artist_albums(user_id, token, artist_id) } : []
        similar_albums = artist ? [] : optional_items { get("Items/#{album["Id"]}/Similar", token, UserId: user_id, Limit: 8).fetch("Items", []) }

        details = {
          item: item,
          album: album,
          tracks: tracks,
          other_albums: music_albums_without_podcasts(other_albums, podcast_library, podcast_album_ids),
          similar_albums: music_albums_without_podcasts(similar_albums.select { |similar| similar["Type"] == "MusicAlbum" }, podcast_library, podcast_album_ids)
        }
        LibraryItemDetailsResponseData.new(details: details, access_token: token)
      end

      def library_collection(collection, page:, query:, genre: nil)
        session = authentication
        user_id = session.fetch("User").fetch("Id")
        token = session.fetch("AccessToken")
        parameters = { UserId: user_id, Limit: 48, StartIndex: (page - 1) * 48, SearchTerm: query, Genres: genre, EnableImages: true }.compact
        response = case collection
        when :artists then get("Artists", token, **parameters)
        when :albums then get("Users/#{user_id}/Items", token, **parameters.merge(Recursive: true, IncludeItemTypes: "MusicAlbum", SortBy: "SortName"))
        when :audiobooks then get("Users/#{user_id}/Items", token, **parameters.merge(Recursive: true, IncludeItemTypes: "AudioBook", SortBy: "SortName"))
        when :podcasts then podcast_shows(user_id, token, **parameters)
        when :playlists then get("Users/#{user_id}/Items", token, **parameters.merge(Recursive: true, IncludeItemTypes: "Playlist", SortBy: "SortName"))
        when :genres then get("MusicGenres", token, **parameters.merge(Limit: 1_000, StartIndex: 0, SortBy: "Name"))
        else raise ArgumentError, "Unsupported collection: #{collection}"
        end

        LibraryCollectionResponseData.new(content: response.fetch("Items", []), total: response.fetch("TotalRecordCount", 0), access_token: token)
      end

      def playback_queue(item_id)
        session = authentication
        user_id = session.fetch("User").fetch("Id")
        token = session.fetch("AccessToken")
        item = get("Users/#{user_id}/Items/#{item_id}", token, Fields: "AlbumArtists")
        items = case item["Type"]
        when "MusicAlbum"
          all_items(user_id, token, ParentId: item["Id"], IncludeItemTypes: "Audio", SortBy: "ParentIndexNumber,IndexNumber", Fields: "AlbumPrimaryImageTag", EnableImages: true, sort_order: "Ascending")
        when "MusicArtist"
          items(user_id, token, limit: 20, ArtistIds: item["Id"], IncludeItemTypes: "Audio", SortBy: "Random")
        when "Playlist"
          playlist_items(item["Id"], user_id, token)
        else
          [ item ]
        end

        PlaybackQueueResponseData.new(items: items, access_token: token)
      end

      def instant_mix(item_id, limit: 12)
        session = authentication
        user_id = session.fetch("User").fetch("Id")
        token = session.fetch("AccessToken")
        items = get(
          "Songs/#{item_id}/InstantMix",
          token,
          UserId: user_id,
          Limit: limit,
          EnableImages: true,
          EnableUserData: true,
          Fields: "AlbumArtists,RunTimeTicks,AlbumPrimaryImageTag"
        ).fetch("Items", [])

        PlaybackQueueResponseData.new(items: items.select { |item| item["Type"] == "Audio" }, access_token: token)
      end

      def update_favorite(item_id:, favorite:)
        session = authentication
        token = session.fetch("AccessToken")
        request_class = favorite ? Net::HTTP::Post : Net::HTTP::Delete
        request = request_class.new(URI.parse("#{base_url}/UserFavoriteItems/#{item_id}"), "X-Emby-Token" => token)
        ensure_success!(perform(request))
      rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNREFUSED
        raise ConnectionError, "Could not reach the server. Check the address and try again."
      end

      def playlists
        session = authentication
        get("Users/#{session.dig("User", "Id")}/Items", session.fetch("AccessToken"), Recursive: true, IncludeItemTypes: "Playlist", SortBy: "SortName", EnableImages: true).fetch("Items", [])
      end

      def create_playlist(name)
        session = authentication
        token = session.fetch("AccessToken")
        uri = URI.parse("#{base_url}/Playlists")
        request = Net::HTTP::Post.new(uri, "X-Emby-Token" => token, "Content-Type" => "application/json")
        request.body = { Name: name, UserId: session.dig("User", "Id"), MediaType: "Audio" }.to_json
        ensure_success!(response = perform(request))
        JSON.parse(response.body).fetch("Id")
      end

      def add_to_playlist(playlist_id:, item_ids: nil, item_id: nil)
        session = authentication
        token = session.fetch("AccessToken")
        uri = URI.parse("#{base_url}/Playlists/#{playlist_id}/Items")
        uri.query = URI.encode_www_form(Ids: Array(item_ids || item_id).join(","), UserId: session.dig("User", "Id"))
        ensure_success!(perform(Net::HTTP::Post.new(uri, "X-Emby-Token" => token)))
      end

      def delete_playlist(playlist_id:)
        session = authentication
        uri = URI.parse("#{base_url}/Items/#{playlist_id}")
        ensure_success!(perform(Net::HTTP::Delete.new(uri, "X-Emby-Token" => session.fetch("AccessToken"))))
      end

      def remove_from_playlist(playlist_id:, entry_id:)
        session = authentication
        uri = URI.parse("#{base_url}/Playlists/#{playlist_id}/Items")
        uri.query = URI.encode_www_form(EntryIds: entry_id)
        ensure_success!(perform(Net::HTTP::Delete.new(uri, "X-Emby-Token" => session.fetch("AccessToken"))))
      end

      def stream_audio(item_id:, range:, access_token: nil)
        session = authentication unless access_token
        token = access_token || session.fetch("AccessToken")
        uri = URI.parse("#{base_url}/Audio/#{item_id}/stream")
        parameters = { Static: true }
        parameters[:UserId] = session.fetch("User").fetch("Id") if session
        uri.query = URI.encode_www_form(parameters)
        headers = { "X-Emby-Token" => token }
        headers["Range"] = range if range.present?
        stream(Net::HTTP::Get.new(uri, headers)) do |response|
          ensure_success!(response)
          yield AudioStreamResponseData.new(
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

      def report_playback(event:, item_id:, position_ticks:, paused:, access_token: nil)
        token = access_token || authentication.fetch("AccessToken")
        response = perform(playback_report_request(event, item_id, position_ticks, paused, token))

        raise AuthenticationError if response.code == "401"

        ensure_success!(response)
        PlaybackReportResponseData.new(access_token: token)
      rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNREFUSED
        raise ConnectionError, "Could not reach the server. Check the address and try again."
      rescue OpenSSL::SSL::SSLError
        raise ConnectionError, "Could not establish a secure connection to the server."
      end

      def update_playback_position(item_id:, position_ticks:, access_token: nil)
        token = access_token || authentication.fetch("AccessToken")
        uri = URI.parse("#{base_url}/UserItems/#{item_id}/UserData")
        response = perform(
          Net::HTTP::Post.new(uri, "X-Emby-Token" => token, "Content-Type" => "application/json").tap do |request|
            request.body = { PlaybackPositionTicks: position_ticks, Played: false }.to_json
          end
        )

        raise AuthenticationError if response.code == "401"

        ensure_success!(response)
        PlaybackReportResponseData.new(access_token: token)
      rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNREFUSED
        raise ConnectionError, "Could not reach the server. Check the address and try again."
      rescue OpenSSL::SSL::SSLError
        raise ConnectionError, "Could not establish a secure connection to the server."
      end

      private

      def authentication
        if access_token.present?
          return { "User" => @resolved_user, "AccessToken" => access_token } if @resolved_user
          return { "User" => @resolved_user = { "Id" => remote_user_id, "Name" => username }, "AccessToken" => access_token } if remote_user_id.present? && username.present?

          return { "User" => @resolved_user = get("Users/Me", access_token), "AccessToken" => access_token }
        end

        response = perform(request)

        raise AuthenticationError if response.code == "401"
        ensure_success!(response)
        JSON.parse(response.body).tap { |session| @resolved_user = session["User"] }
      rescue JSON::ParserError, KeyError
        raise ConnectionError, "The server returned an unexpected response."
      rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNREFUSED
        raise ConnectionError, "Could not reach the server. Check the address and try again."
      rescue OpenSSL::SSL::SSLError
        raise ConnectionError, "Could not establish a secure connection to the server."
      end

      attr_reader :base_url, :username, :password, :access_token, :remote_user_id, :http

      def items(user_id, token, limit: 8, sort_order: "Descending", **parameters)
        requested_fields = parameters.delete(:Fields)
        get(
          "Users/#{user_id}/Items",
          token,
          **parameters.merge(
            Recursive: true,
            Limit: limit,
            SortOrder: sort_order,
            EnableImages: true,
            EnableImageTypes: "Primary",
            ImageTypeLimit: 1,
            Fields: [ "DateCreated,PrimaryImageAspectRatio,ParentId", requested_fields ].compact.join(",")
          )
        ).fetch("Items", [])
      end

      def all_items(user_id, token, sort_order:, **parameters)
        start_index = 0
        all_items = []

        loop do
          response = get(
            "Users/#{user_id}/Items",
            token,
            **parameters.merge(Recursive: true, Limit: 100, StartIndex: start_index, SortOrder: sort_order)
          )
          page = response.fetch("Items", [])
          all_items.concat(page)
          break if page.empty? || all_items.size >= response.fetch("TotalRecordCount", 0)

          start_index += page.size
        end

        all_items.sort_by do |item|
          [ item["ParentIndexNumber"] || 1, item["IndexNumber"] || Float::INFINITY, item["Name"] ]
        end
      end

      def playlist_items(playlist_id, user_id, token)
        get("Playlists/#{playlist_id}/Items", token, UserId: user_id, Limit: 1_000, EnableImages: true, EnableUserData: true, Fields: "AlbumArtists,RunTimeTicks,AlbumPrimaryImageTag").fetch("Items", [])
      end

      def playlist_details(item, user_id, token)
        LibraryItemDetailsResponseData.new(
          details: { item: item, album: item, tracks: playlist_items(item.fetch("Id"), user_id, token), other_albums: [], similar_albums: [], kind: :playlist },
          access_token: token
        )
      end

      def artist_albums(user_id, token, artist_id)
        albums = []
        start_index = 0

        loop do
          response = get(
            "Users/#{user_id}/Items",
            token,
            AlbumArtistIds: artist_id,
            IncludeItemTypes: "MusicAlbum",
            SortBy: "PremiereDate",
            SortOrder: "Descending",
            Recursive: true,
            Limit: 100,
            StartIndex: start_index,
            Fields: "PremiereDate,ProductionYear,DateCreated"
          )
          page = response.fetch("Items", [])
          albums.concat(page)
          break if page.empty? || albums.size >= response.fetch("TotalRecordCount", 0)

          start_index += page.size
        end

        albums.sort_by { |album| [ album["PremiereDate"].to_s, album["ProductionYear"].to_s, album["DateCreated"].to_s, album["Name"].to_s ] }.reverse
      end

      def podcast_items(user_id, token, podcast_library: nil, **parameters)
        podcast_library ||= podcast_library(user_id, token)
        return { "Items" => [], "TotalRecordCount" => 0 } unless podcast_library

        get(
          "Users/#{user_id}/Items",
          token,
          **{ ParentId: podcast_library.fetch("Id"), Recursive: true, IncludeItemTypes: "Audio", SortBy: "DateCreated", SortOrder: "Descending" }.merge(parameters)
        )
      end

      def podcast_shows(user_id, token, **parameters)
        podcast_library = podcast_library(user_id, token)
        return { "Items" => [], "TotalRecordCount" => 0 } unless podcast_library

        get(
          "Users/#{user_id}/Items",
          token,
          **{ ParentId: podcast_library.fetch("Id"), Recursive: true, IncludeItemTypes: "MusicAlbum", SortBy: "SortName" }.merge(parameters)
        )
      end

      def item_ancestors(item_id, token)
        response = get("Items/#{item_id}/Ancestors", token)
        response.is_a?(Array) ? response : response.fetch("Items", [])
      end

      def resume_items(user_id, token, **parameters)
        get(
          "Users/#{user_id}/Items/Resume",
          token,
          **parameters.merge(
            Limit: 8,
            EnableImages: true,
            EnableImageTypes: "Primary",
            ImageTypeLimit: 1,
            Fields: "DateCreated,PrimaryImageAspectRatio,ParentId"
          )
        ).fetch("Items", [])
      end

      def podcast_library(user_id, token)
        get("Users/#{user_id}/Views", token).fetch("Items", []).find do |library|
          library.fetch("Name", "").match?(/podcast/i)
        end
      end

      def media_kind(item, user_id, token, podcast_library)
        return :audiobook if item["Type"] == "AudioBook"
        return :music unless item["Type"] == "Audio" && podcast_library

        item_ancestors(item.fetch("Id"), token).pluck("Id").include?(podcast_library.fetch("Id")) ? :podcast : :music
      end

      def non_music_item_details(item, token, kind)
        LibraryItemDetailsResponseData.new(
          details: {
            item: item,
            album: item,
            kind: kind,
            chapters: kind == :audiobook ? optional_items { get("Items/#{item.fetch("Id")}/Chapters", token).fetch("Items", []) } : [],
            tracks: [],
            other_albums: [],
            similar_albums: []
          },
          access_token: token
        )
      end

      def podcast_album_ids(user_id, token, podcast_library)
        get(
          "Users/#{user_id}/Items",
          token,
          ParentId: podcast_library.fetch("Id"),
          Recursive: true,
          IncludeItemTypes: "MusicAlbum",
          Fields: "ParentId",
          Limit: 1_000
        ).fetch("Items", []).pluck("Id")
      end

      def music_albums_without_podcasts(albums, podcast_library, podcast_album_ids)
        return albums unless podcast_library

        albums.reject { |album| album["ParentId"] == podcast_library["Id"] || podcast_album_ids.include?(album["Id"]) }
      end

      def music_songs_without_podcasts(songs, podcast_album_ids)
        songs.reject { |song| podcast_album_ids.include?(song["AlbumId"]) }
      end

      def personalized_genres(most_played_songs, recently_played_songs)
        genre_scores = Hash.new(0)
        most_played_songs.each do |song|
          add_genre_scores(genre_scores, song, [ song.dig("UserData", "PlayCount").to_i, 1 ].max)
        end
        recently_played_songs.each { |song| add_genre_scores(genre_scores, song, 1) }

        genre_scores.sort_by { |genre, score| [ -score, genre ] }.first(4).map { |genre, _| { "Name" => genre } }
      end

      def add_genre_scores(genre_scores, item, weight)
        item.fetch("Genres", []).flat_map { |genre| genre.split(";") }.map(&:strip).reject(&:blank?).each do |genre|
          genre_scores[genre] += weight
        end
      end

      def played_items(items)
        items.select { |item| item.dig("UserData", "PlayCount").to_i.positive? }.first(8)
      end

      def get(path, token, **parameters)
        uri = URI.parse("#{base_url}/#{path}")
        uri.query = URI.encode_www_form(parameters)
        headers = token.present? ? { "X-Emby-Token" => token } : {}
        response = perform(Net::HTTP::Get.new(uri, headers))

        ensure_success!(response)
        JSON.parse(response.body)
      rescue JSON::ParserError, KeyError
        raise ConnectionError, "The server returned an unexpected response."
      end

      def playback_report_request(event, item_id, position_ticks, paused, token)
        path = case event
        when "started" then "Sessions/Playing"
        when "progress" then "Sessions/Playing/Progress"
        when "stopped" then "Sessions/Playing/Stopped"
        else raise ArgumentError, "Unsupported playback event"
        end
        uri = URI.parse("#{base_url}/#{path}")
        Net::HTTP::Post.new(uri, "X-Emby-Token" => token, "Content-Type" => "application/json").tap do |request|
          request.body = {
            ItemId: item_id,
            PositionTicks: position_ticks,
            CanSeek: true,
            IsPaused: paused,
            PlayMethod: "DirectPlay"
          }.to_json
        end
      end

      def optional_items
        yield
      rescue ConnectionError
        []
      end

      public

      def artwork(item_id:, tag:, access_token:)
        parameters = tag.present? ? { tag: tag } : {}
        uri = URI.parse("#{base_url}/Items/#{item_id}/Images/Primary")
        uri.query = URI.encode_www_form(parameters) if parameters.any?
        response = perform(Net::HTTP::Get.new(uri, "X-Emby-Token" => access_token))

        ensure_success!(response)
        ArtworkResponseData.new(body: response.body, content_type: response["Content-Type"] || "image/jpeg")
      end

      private

      def perform(http_request)
        http.start(http_request.uri.host, http_request.uri.port, use_ssl: http_request.uri.scheme == "https", open_timeout: 5, read_timeout: 10) do |connection|
          connection.request(http_request)
        end
      end

      def stream(http_request)
        http.start(http_request.uri.host, http_request.uri.port, use_ssl: http_request.uri.scheme == "https", open_timeout: 5, read_timeout: 10) do |connection|
          connection.request(http_request) { |response| yield response }
        end
      end

      def ensure_success!(response)
        raise ConnectionError, "The server returned HTTP #{response.code}." unless response.is_a?(Net::HTTPSuccess)
      end

      def endpoint
        @endpoint ||= URI.parse("#{base_url}/Users/AuthenticateByName")
      end

      public

      def initiate_quick_connect
        response = perform(Net::HTTP::Post.new(URI.parse("#{base_url}/QuickConnect/Initiate"), "X-Emby-Authorization" => authorization_header))
        ensure_success!(response)
        JSON.parse(response.body)
      rescue JSON::ParserError
        raise ConnectionError, "The server returned an unexpected response."
      end

      def quick_connect_state(secret)
        get("QuickConnect/Connect", nil, secret: secret)
      end

      def authenticate_with_quick_connect(secret)
        request = Net::HTTP::Post.new(URI.parse("#{base_url}/Users/AuthenticateWithQuickConnect"), "Content-Type" => "application/json", "X-Emby-Authorization" => authorization_header)
        request.body = { Secret: secret }.to_json
        response = perform(request)
        raise AuthenticationError if response.code == "401"
        ensure_success!(response)
        JSON.parse(response.body)
      rescue JSON::ParserError
        raise ConnectionError, "The server returned an unexpected response."
      end

      def request
        Net::HTTP::Post.new(
          endpoint,
          {
            "Content-Type" => "application/json",
            "X-Emby-Authorization" => authorization_header
          }
        ).tap { |post| post.body = { Username: username, Pw: password }.to_json }
      end

      def authorization_header
        'MediaBrowser Client="Sonzra", Device="Sonzra", DeviceId="sonzra-web", Version="1.0.0"'
      end
    end
  end
end
