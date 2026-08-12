class PlaybackQueuesController < ApplicationController
  def show
    server_connection = current_user.server_connections.find(params.expect(:server_connection_id))
    result = ServerConnections::FetchPlaybackQueue.new(server_connection, params.expect(:item_id)).call
    return render json: { error: result.message }, status: :bad_gateway unless result.success?

    session[:server_access_tokens] = session.fetch(:server_access_tokens, {}).merge(server_connection.id.to_s => result.access_token)
    render json: {
      items: result.items.map do |item|
        {
          source: audio_server_connection_path(server_connection, item.fetch("Id")),
          item_id: item.fetch("Id"),
          reporting_url: playback_reports_server_connection_path(server_connection),
          title: item.fetch("Name"),
          artist: item["AlbumArtist"] || item["Artists"]&.join(", ") || "Unknown artist",
          album_id: item["AlbumId"],
          album: item["Album"],
          album_artist: item["AlbumArtist"],
          duration: helpers.track_duration(item["RunTimeTicks"]),
          artwork: helpers.library_artwork_path(server_connection, item) || "/brand/sonzra-mark.svg",
          favorite: item.dig("UserData", "IsFavorite"),
          radio_url: radio_tracks_server_connection_path(server_connection, item.fetch("Id")),
          radio_eligible: true
        }
      end
    }
  end
end
