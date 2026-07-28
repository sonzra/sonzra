module ApplicationHelper
  def library_artwork_path(server_connection, item)
    image_tags = item["ImageTags"] || {}
    item_id = image_tags["Primary"] ? item["Id"] : item["AlbumId"]
    image_tag = image_tags["Primary"] || item["AlbumPrimaryImageTag"]
    return unless item_id && image_tag

    artwork_server_connection_path(server_connection, item_id, tag: image_tag)
  end

  def music_genre_names(genres)
    genres.flat_map { |genre| genre.fetch("Name", "").split(";") }.map(&:strip).reject(&:blank?).uniq
  end

  def track_duration(run_time_ticks)
    total_seconds = run_time_ticks.to_i / 10_000_000
    format("%d:%02d", total_seconds / 60, total_seconds % 60)
  end
end
