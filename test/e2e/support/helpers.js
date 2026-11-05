import { execSync } from "node:child_process"

export async function signInAs(page, email = "one@example.com", password = "password") {
  await page.goto("/session/new")
  await page.fill("input[name='email_address']", email)
  await page.fill("input[name='password']", password)
  await page.click("input[type='submit']")
  await page.waitForURL("/")
}

export function seedTestLibrary() {
  const script = `
    ActiveRecord::Base.transaction do
      server = MediaServer.find_or_create_by!(base_url: "http://127.0.0.1:9999") do |s|
        s.name = "Mock Jellyfin"
        s.provider = :jellyfin
      end

      user = User.find_by!(email_address: "one@example.com")
      conn = ServerConnection.find_or_create_by!(user: user, media_server: server) do |c|
        c.username = "mockuser"
        c.password = "secret"
      end

      mix = user.recommendation_collections.find_or_create_by!(server_connection: conn, strategy: "friday_rediscovery") do |m|
        m.title = "Weekend Discovery"
        m.subtitle = "Mocked tracks for testing"
        m.period_date = Date.current
        m.generated_at = Time.current
      end

      if mix.recommendation_tracks.empty?
        mix.recommendation_tracks.create!(
          item_id: "e2e-track-1",
          title: "Starlight Echoes",
          artist: "Cosmic Sound",
          album: "Galactic Journey",
          duration: 215,
          position: 1
        )
      end

      puts "SEED_COMPLETE:conn_id=#{conn.id}:mix_id=#{mix.id}"
    end
  `

  const output = execSync(
    `ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY=9a70b7d5e49390f6f7e6d8b4a9012c3d ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY=cf63a9d772e4b0086e5a4c3d2f1908ab ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT=7c58d3e9a0bf4c2d1e6f9a3b8d0c7e5f RAILS_ENV=test bin/rails runner '${script}'`,
    { encoding: "utf-8" }
  )

  const match = output.match(/SEED_COMPLETE:conn_id=(\d+):mix_id=(\d+)/)
  if (!match) throw new Error(`Failed to seed test library: ${output}`)
  return { connectionId: match[1], mixId: match[2] }
}

export function cleanTestLibrary() {
  const script = `
    RecommendationCollection.destroy_all
    ServerConnection.destroy_all
    MediaServer.destroy_all
  `

  execSync(
    `ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY=9a70b7d5e49390f6f7e6d8b4a9012c3d ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY=cf63a9d772e4b0086e5a4c3d2f1908ab ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT=7c58d3e9a0bf4c2d1e6f9a3b8d0c7e5f RAILS_ENV=test bin/rails runner '${script}'`,
    { encoding: "utf-8" }
  )
}
