module Api
  module V1
    module Library
      class ItemsController < BaseController
        def show
          return render json: { error: "No server connection found" }, status: :unprocessable_entity unless current_connection

          service = ServerConnections::FetchLibraryItemDetails.new(
            current_connection,
            params.expect(:id),
            user: current_user,
            access_token: server_access_token(current_connection),
            device_id: client_device_id
          )
          result = service.call

          return render_service_error(result) unless result.success?

          store_server_access_token(current_connection, result.access_token)
          clear_connection_alert(current_connection)

          render json: serialize_details(result.details)
        end

        private

        def serialize_details(details)
          item = details[:item] || {}
          kind = details.fetch(:kind, :music)

          if item["Type"] == "MusicArtist"
            serialize_artist_details(details)
          elsif kind.in?(%i[audiobook podcast])
            serialize_longform_details(details)
          else
            serialize_album_details(details)
          end
        end

        def serialize_artist_details(details)
          item = details[:item]
          albums = format_album_list(details[:other_albums])

          {
            id: item["Id"].to_s,
            name: item["Name"],
            type: "MusicArtist",
            artwork_url: artwork_url_for(current_connection, item["Id"]),
            server_connection_id: current_connection.id,
            overview: item["Overview"],
            discography: albums,
            albums: albums,
            tracks: format_tracks(details[:tracks])
          }
        end

        def serialize_album_details(details)
          item = details[:item] || {}
          album = details[:album] || item
          year = album["ProductionYear"]&.to_s.presence || album["PremiereDate"]&.to_s&.slice(0, 4)

          {
            id: album["Id"].to_s,
            name: album["Name"],
            type: album["Type"] || "MusicAlbum",
            artist: album["AlbumArtist"] || item["AlbumArtist"] || item["Artists"]&.join(", ") || "Unknown artist",
            year: year,
            artwork_url: artwork_url_for(current_connection, album["Id"]),
            server_connection_id: current_connection.id,
            overview: album["Overview"] || item["Overview"],
            tracks: format_tracks(details[:tracks], album),
            other_albums: format_album_list(details[:other_albums]),
            similar_albums: format_album_list(details[:similar_albums])
          }
        end

        def serialize_longform_details(details)
          item = details[:item]
          kind = details.fetch(:kind, :music)
          ticks = item["RunTimeTicks"].to_i
          position_ticks = item.dig("UserData", "PlaybackPositionTicks").to_i

          {
            id: item["Id"].to_s,
            name: item["Name"],
            type: item["Type"],
            kind: kind,
            artist: item["AlbumArtist"] || item["Artists"]&.join(", ") || item["Album"],
            artwork_url: artwork_url_for(current_connection, item["Id"]),
            stream_url: audio_stream_url(current_connection, item["Id"]),
            audio_url: audio_stream_url(current_connection, item["Id"]),
            duration: helpers.track_duration(ticks),
            duration_seconds: (ticks.to_f / 10_000_000).round,
            duration_ticks: ticks,
            playback_position_ticks: position_ticks,
            playback_position_seconds: (position_ticks.to_f / 10_000_000).round(1),
            server_connection_id: current_connection.id,
            chapters: details[:chapters] || []
          }
        end

        def format_tracks(tracks, parent_album = nil)
          Array(tracks).map do |track|
            ticks = track["RunTimeTicks"].to_i
            {
              id: track["Id"].to_s,
              title: track["Name"],
              artist: track["AlbumArtist"] || track["Artists"]&.join(", ") || parent_album&.dig("AlbumArtist") || "Unknown artist",
              album: parent_album&.dig("Name") || track["Album"],
              track_number: track["IndexNumber"],
              disc_number: track["ParentIndexNumber"],
              duration: helpers.track_duration(ticks),
              duration_seconds: (ticks.to_f / 10_000_000).round,
              duration_ticks: ticks,
              stream_url: audio_stream_url(current_connection, track["Id"]),
              audio_url: audio_stream_url(current_connection, track["Id"]),
              artwork_url: artwork_url_for(current_connection, track["Id"]),
              server_connection_id: current_connection.id
            }
          end
        end

        def format_album_list(albums)
          Array(albums).map do |album|
            year = album["ProductionYear"]&.to_s.presence || album["PremiereDate"]&.to_s&.slice(0, 4)
            {
              id: album["Id"].to_s,
              name: album["Name"],
              artist: album["AlbumArtist"] || "Unknown artist",
              year: year,
              artwork_url: artwork_url_for(current_connection, album["Id"]),
              server_connection_id: current_connection.id
            }
          end
        end
      end
    end
  end
end
