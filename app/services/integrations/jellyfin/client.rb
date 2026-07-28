require "json"
require "net/http"
require "uri"

module Integrations
  module Jellyfin
    class Client
      class AuthenticationError < StandardError; end
      class ConnectionError < StandardError; end

      def initialize(base_url:, username:, password:, http: Net::HTTP)
        @base_url = base_url
        @username = username
        @password = password
        @http = http
      end

      def authenticate
        authentication.fetch("User").fetch("Name")
      end

      def home_content
        session = authentication
        user_id = session.fetch("User").fetch("Id")
        token = session.fetch("AccessToken")
        podcast_library = podcast_library(user_id, token)
        podcast_album_ids = podcast_library ? podcast_album_ids(user_id, token, podcast_library) : []

        content = {
          user_name: session.fetch("User").fetch("Name"),
          recently_played: items(user_id, token, SortBy: "DatePlayed", IncludeItemTypes: "Audio"),
          recently_added_albums: music_albums_without_podcasts(items(user_id, token, SortBy: "DateCreated", IncludeItemTypes: "MusicAlbum"), podcast_library, podcast_album_ids),
          recently_added_artists: get("Artists", token, UserId: user_id, Limit: 8).fetch("Items", []),
          genres: get("MusicGenres", token, UserId: user_id, Limit: 8).fetch("Items", []),
          most_played_songs: played_items(items(user_id, token, limit: 48, SortBy: "PlayCount", EnableUserData: true, IncludeItemTypes: "Audio")),
          most_played_albums: music_albums_without_podcasts(played_items(items(user_id, token, limit: 48, SortBy: "PlayCount", EnableUserData: true, IncludeItemTypes: "MusicAlbum")), podcast_library, podcast_album_ids),
          recently_added_audiobooks: items(user_id, token, SortBy: "DateCreated", IncludeItemTypes: "AudioBook"),
          recently_added_podcasts: podcast_library ? podcast_items(user_id, token, podcast_library: podcast_library, SortBy: "DateCreated", SortOrder: "Descending").fetch("Items", []) : []
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
        item = get("Users/#{user_id}/Items/#{item_id}", token, Fields: "Overview,Genres,DateCreated,RunTimeTicks,AlbumArtists")
        artist = item["Type"] == "MusicArtist"
        album = item["Type"] == "Audio" && item["AlbumId"] ? get("Users/#{user_id}/Items/#{item["AlbumId"]}", token) : item
        tracks = album["Type"] == "MusicAlbum" ? all_items(user_id, token, ParentId: album["Id"], IncludeItemTypes: "Audio", SortBy: "ParentIndexNumber,IndexNumber", sort_order: "Ascending") : []
        artist_id = artist ? item["Id"] : album.dig("AlbumArtists", 0, "Id") || item.dig("AlbumArtists", 0, "Id")

        details = {
          item: item,
          album: album,
          tracks: tracks,
          other_albums: artist_id ? optional_items { items(user_id, token, AlbumArtistIds: artist_id, IncludeItemTypes: "MusicAlbum") } : [],
          similar_albums: artist ? [] : optional_items { get("Items/#{album["Id"]}/Similar", token, UserId: user_id, Limit: 8).fetch("Items", []) }
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
        when :podcasts then podcast_items(user_id, token, **parameters)
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
        else
          [ item ]
        end

        PlaybackQueueResponseData.new(items: items, access_token: token)
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

      private

      def authentication
        response = perform(request)

        raise AuthenticationError if response.code == "401"
        ensure_success!(response)
        JSON.parse(response.body)
      rescue JSON::ParserError, KeyError
        raise ConnectionError, "The server returned an unexpected response."
      rescue Net::OpenTimeout, Net::ReadTimeout, SocketError, Errno::ECONNREFUSED
        raise ConnectionError, "Could not reach the server. Check the address and try again."
      rescue OpenSSL::SSL::SSLError
        raise ConnectionError, "Could not establish a secure connection to the server."
      end

      attr_reader :base_url, :username, :password, :http

      def items(user_id, token, limit: 8, sort_order: "Descending", **parameters)
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
            Fields: "DateCreated,PrimaryImageAspectRatio,ParentId"
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

      def podcast_items(user_id, token, podcast_library: nil, **parameters)
        podcast_library ||= podcast_library(user_id, token)
        return { "Items" => [], "TotalRecordCount" => 0 } unless podcast_library

        get(
          "Users/#{user_id}/Items",
          token,
          **parameters.merge(ParentId: podcast_library.fetch("Id"), Recursive: true, IncludeItemTypes: "Audio", SortBy: "DateCreated", SortOrder: "Descending")
        )
      end

      def podcast_library(user_id, token)
        get("Users/#{user_id}/Views", token).fetch("Items", []).find do |library|
          library.fetch("Name", "").match?(/podcast/i)
        end
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

      def played_items(items)
        items.select { |item| item.dig("UserData", "PlayCount").to_i.positive? }.first(8)
      end

      def get(path, token, **parameters)
        uri = URI.parse("#{base_url}/#{path}")
        uri.query = URI.encode_www_form(parameters)
        response = perform(Net::HTTP::Get.new(uri, "X-Emby-Token" => token))

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
