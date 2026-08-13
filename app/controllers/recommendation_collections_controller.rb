class RecommendationCollectionsController < ApplicationController
  def index
    @recommendation_collections = current_user.recommendation_collections.where(server_connection: current_server_connection).includes(:recommendation_tracks, :server_connection).order(generated_at: :desc)
  end

  def show
    @collection = current_user.recommendation_collections.includes(:recommendation_tracks, :server_connection).find(params.expect(:id))
    @tracks = visible_tracks
    @media_detail_header = true
    @media_detail_title = @collection.title
    @back_path = recommendation_collections_path
    @back_label = "Your mixes"

    respond_to do |format|
      format.html
      format.json do
        connection = @collection.server_connection
        render json: {
          items: @tracks.map do |track|
        {
          source: audio_server_connection_path(connection, track.item_id), item_id: track.item_id,
          reporting_url: playback_reports_server_connection_path(connection), title: track.title,
          artist: track.artist, album: track.album, album_artist: track.album_artist, album_id: track.album_id,
          artwork: artwork_server_connection_path(connection, track.artwork_item_id), duration: track.duration,
          radio_url: radio_tracks_server_connection_path(connection, track.item_id), radio_eligible: true
        }
          end
        }
      end
    end
  end

  def events
    collection = current_user.recommendation_collections.find(params.expect(:id))
    collection.recommendation_collection_events.create!(event_type: params.expect(:event_type), occurred_at: Time.current)
    head :created
  end

  private

  def visible_tracks
    hidden_artists = current_user.hidden_artists.where(server_connection: @collection.server_connection)
    hidden_ids = hidden_artists.pluck(:artist_id)
    hidden_names = hidden_artists.pluck(:name)
    @collection.recommendation_tracks.reject { |track| hidden_ids.include?(track.artist_id) || (track.artist_id.blank? && hidden_names.include?(track.artist)) }
  end
end
