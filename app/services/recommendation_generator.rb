class RecommendationGenerator
  MAX_TRACKS = 20
  MAX_TRACKS_PER_ARTIST = 3
  MAX_TRACKS_PER_ALBUM = 2

  def self.scheduled?(strategy, period_date)
    case strategy
    when "friday_rediscovery" then period_date.friday?
    when "more_from_artist" then period_date.wednesday?
    when "top_of_month" then period_date.monday? && (period_date + 7.days).month != period_date.month
    else true
    end
  end

  def initialize(user:, strategy:, period_date:, client: nil)
    @user, @strategy, @period_date, @client = user, strategy, period_date, client
  end

  def call
    run = @user.recommendation_runs.find_or_create_by!(strategy: @strategy, period_date: @period_date)
    return run.recommendation_collection if run.status == "generated" && run.recommendation_collection

    connection = @user.server_connections.order(:created_at).first
    return fail!(run, "No Jellyfin server connection") unless connection

    tracks, title, subtitle = candidates(connection)
    selected = if @strategy == "top_of_month"
      tracks.first(MAX_TRACKS)
    elsif @strategy == "more_from_artist"
      diversify(tracks, max_tracks_per_artist: MAX_TRACKS)
    else
      diversify(tracks)
    end
    return fail!(run, "Not enough listening history") if selected.empty?

    collection = RecommendationCollection.find_or_initialize_by(user: @user, strategy: @strategy, period_date: @period_date)
    collection.assign_attributes(server_connection: connection, title:, subtitle:, generated_at: Time.current)
    collection.save!
    collection.recommendation_tracks.delete_all
    selected.each_with_index { |track, index| collection.recommendation_tracks.create!(track_attributes(track).merge(position: index + 1)) }
    run.update!(status: "generated", generated_at: Time.current, error_message: nil, recommendation_collection: collection)
    collection
  rescue Integrations::Jellyfin::Client::AuthenticationError, Integrations::Jellyfin::Client::ConnectionError => error
    fail!(run, error.message)
  end

  private

  def candidates(connection)
    if @strategy == "top_of_month"
      items = client_for(connection).monthly_top_tracks(@period_date)
      items = client_for(connection).recommendation_tracks_by_ids(monthly_top_item_ids) if items.empty?
      [ items, "Top of #{@period_date.strftime("%B")}", "Your most-played tracks this month" ]
    else
      items = client_for(connection).recommendation_tracks(@strategy, @period_date)
      if @strategy == "best_of_genre"
      genre = items.first&.dig("Genres")&.first || "your library"
      [ items, "Best of #{genre}", "A daily mix from your most-played genre" ]
      elsif @strategy == "more_from_artist"
        artist = items.first&.fetch("AlbumArtist", nil) || "your favourite artist"
        [ items, "More from #{artist}", "Inspired by your listening this week" ]
      else
      [ items, "Friday Rediscovery", "Tracks you loved and have not heard in a while" ]
      end
    end
  end

  def monthly_top_item_ids
    @user.listening_events.where(occurred_at: @period_date.beginning_of_month..@period_date.end_of_day)
      .group(:item_id).order(Arel.sql("COUNT(*) DESC"), :item_id).limit(MAX_TRACKS).count.keys
  end

  def client_for(connection)
    @client ||= Integrations::Jellyfin::Client.new(**connection.client_options)
  end

  def diversify(items, max_tracks_per_artist: MAX_TRACKS_PER_ARTIST)
    artist_counts = Hash.new(0)
    album_counts = Hash.new(0)
    items.each_with_object([]) do |item, selected|
      break selected if selected.size == MAX_TRACKS
      artist = item["AlbumArtist"] || item["Artists"]&.first || "Unknown artist"
      album = item["AlbumId"] || item["Album"] || item["Id"]
      next if artist_counts[artist] >= max_tracks_per_artist || album_counts[album] >= MAX_TRACKS_PER_ALBUM

      artist_counts[artist] += 1
      album_counts[album] += 1
      selected << item
    end
  end

  def track_attributes(item)
    { item_id: item.fetch("Id"), title: item.fetch("Name"), artist: item["AlbumArtist"] || item["Artists"]&.join(", "), album: item["Album"], album_artist: item["AlbumArtist"], album_id: item["AlbumId"], artwork_item_id: item["AlbumId"] || item["Id"], duration: ApplicationController.helpers.track_duration(item["RunTimeTicks"]), genre: item["Genres"]&.first }
  end

  def fail!(run, message)
    run.update!(status: "failed", error_message: message)
    nil
  end
end
