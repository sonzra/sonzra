import { defineConfig, devices } from "@playwright/test"

const PORT = process.env.PORT || 3100
const BASE_URL = process.env.PLAYWRIGHT_BASE_URL || `http://127.0.0.1:${PORT}`

export default defineConfig({
  testDir: "./test/e2e",
  timeout: 30 * 1000,
  expect: {
    timeout: 5000
  },
  fullyParallel: true,
  forbidOnly: Boolean(process.env.CI),
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: [
    [ "list" ],
    [ "html", { open: "never", outputFolder: "playwright-report" } ]
  ],
  use: {
    baseURL: BASE_URL,
    trace: "on-first-retry",
    screenshot: process.env.SCREENSHOT || "only-on-failure",
    video: "retain-on-failure"
  },
  projects: [
    {
      name: "chromium",
      use: { ...devices["Desktop Chrome"] }
    },
    {
      name: "mobile-chrome",
      use: { ...devices["Pixel 5"] }
    }
  ],
  webServer: {
    command: `ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY=9a70b7d5e49390f6f7e6d8b4a9012c3d ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY=cf63a9d772e4b0086e5a4c3d2f1908ab ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT=7c58d3e9a0bf4c2d1e6f9a3b8d0c7e5f RAILS_ENV=test bin/rails server -p ${PORT} -b 127.0.0.1`,
    url: `${BASE_URL}/up`,
    reuseExistingServer: !process.env.CI,
    timeout: 60 * 1000
  }
})
