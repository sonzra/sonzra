import { execSync } from "node:child_process"

export default async function globalSetup() {
  execSync(
    "ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY=9a70b7d5e49390f6f7e6d8b4a9012c3d ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY=cf63a9d772e4b0086e5a4c3d2f1908ab ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT=7c58d3e9a0bf4c2d1e6f9a3b8d0c7e5f RAILS_ENV=test bin/rails runner 'Notification.destroy_all; ServerConnection.destroy_all; MediaServer.destroy_all; User.destroy_all' && ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY=9a70b7d5e49390f6f7e6d8b4a9012c3d ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY=cf63a9d772e4b0086e5a4c3d2f1908ab ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT=7c58d3e9a0bf4c2d1e6f9a3b8d0c7e5f RAILS_ENV=test bin/rails db:fixtures:load",
    { stdio: "inherit" }
  )
}
