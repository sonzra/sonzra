class RadioTracksController < ApplicationController
  def show
    server_connection = current_user.server_connections.find(params.expect(:server_connection_id))
    result = ServerConnections::FetchRadioTracks.new(
      server_connection,
      params.expect(:item_id),
      limit: params[:limit].presence&.to_i&.clamp(1, 12) || 12,
      remote_user_id: session.dig(:server_remote_user_ids, server_connection.id.to_s)
    ).call
    return render json: { error: result.message }, status: :bad_gateway unless result.success?

    session[:server_access_tokens] = session.fetch(:server_access_tokens, {}).merge(server_connection.id.to_s => result.access_token)
    render json: {
      items: HiddenArtists::Filter.new(current_user, server_connection).items(result.items).map do |item|
        {
          source: audio_server_connection_path(server_connection, item.fetch("Id")),
          item_id: item.fetch("Id"),
          reporting_url: playback_reports_server_connection_path(server_connection),
          title: item.fetch("Name"),
          artist: item["AlbumArtist"] || item["Artists"]&.join(", ") || "Unknown artist",
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
