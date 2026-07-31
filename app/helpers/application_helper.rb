module ApplicationHelper
  def library_artwork_path(server_connection, item)
    image_tags = item["ImageTags"] || {}
    item_id = image_tags["Primary"] ? item["Id"] : item["AlbumId"]
    image_tag = image_tags["Primary"] || item["AlbumPrimaryImageTag"]
    return unless item_id && image_tag

    artwork_server_connection_path(server_connection, item_id, tag: image_tag)
  end

  def media_artwork_path(server_connection, item)
    library_artwork_path(server_connection, item) || "/brand/sonzra-mark.svg"
  end

  def music_genre_names(genres)
    genres.flat_map { |genre| genre.fetch("Name", "").split(";") }.map(&:strip).reject(&:blank?).uniq
  end

  def track_duration(run_time_ticks)
    total_seconds = run_time_ticks.to_i / 10_000_000
    format("%d:%02d", total_seconds / 60, total_seconds % 60)
  end

  def playback_position(item)
    item.dig("UserData", "PlaybackPositionTicks").to_i / 10_000_000.0
  end

  def playback_progress(item)
    duration = item["RunTimeTicks"].to_f
    return 0 if duration.zero?

    [ (item.dig("UserData", "PlaybackPositionTicks").to_f / duration * 100).round, 100 ].min
  end

  def people_with_role(item, role)
    item.fetch("People", []).select { |person| person["Type"] == role }.pluck("Name").join(", ")
  end
end
