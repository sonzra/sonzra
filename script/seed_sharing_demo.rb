ActiveRecord::Base.transaction do
  server = MediaServer.find_or_create_by!(base_url: "http://127.0.0.1:9999") do |s|
    s.name = "Home Jellyfin"
    s.provider = :jellyfin
  end

  user = User.find_or_create_by!(email_address: "one@example.com") do |u|
    u.password = "password"
  end
  sarah = User.find_or_create_by!(email_address: "sarah@example.com") do |u|
    u.password = "password"
  end
  alex = User.find_or_create_by!(email_address: "alex@example.com") do |u|
    u.password = "password"
  end

  conn = ServerConnection.find_or_create_by!(user: user, media_server: server) do |c|
    c.username = "mockuser"
    c.password = "secret"
  end
  ServerConnection.find_or_create_by!(user: sarah, media_server: server) do |c|
    c.username = "sarah"
    c.password = "secret"
  end

  # Create recommendation collection for tracks browsing
  mix = user.recommendation_collections.find_or_create_by!(server_connection: conn, strategy: "friday_rediscovery") do |m|
    m.title = "Weekend Discovery"
    m.subtitle = "Mocked tracks for testing"
    m.period_date = Date.current
    m.generated_at = Time.current
  end

  if mix.recommendation_tracks.empty?
    mix.recommendation_tracks.create!(
      item_id: "track-m83",
      title: "Midnight City",
      artist: "M83",
      album: "Hurry Up, We're Dreaming",
      duration: 243,
      position: 1
    )
  end

  user.notifications.destroy_all
  user.notifications.create!(
    sender: sarah,
    media_server: server,
    title: "Midnight City",
    artist: "M83",
    album: "Hurry Up, We're Dreaming",
    item_id: "track-m83",
    note: "Turn the volume up for the outro solo!",
    created_at: 5.minutes.ago
  )
  user.notifications.create!(
    sender: alex,
    media_server: server,
    title: "Solaris",
    artist: "Photay",
    album: "Onism",
    item_id: "track-photay",
    note: "Great ambient track for deep work sessions",
    created_at: 1.hour.ago
  )
  puts "SEED_COMPLETE:conn_id=#{conn.id}:mix_id=#{mix.id}"
end
