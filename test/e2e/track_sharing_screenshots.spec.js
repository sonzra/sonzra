import { expect, test } from "@playwright/test"
import { signInAs } from "./support/helpers.js"
import { execSync } from "node:child_process"
import path from "node:path"
import fs from "node:fs"

function seedSharingData() {
  const output = execSync(
    "ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY=9a70b7d5e49390f6f7e6d8b4a9012c3d ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY=cf63a9d772e4b0086e5a4c3d2f1908ab ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT=7c58d3e9a0bf4c2d1e6f9a3b8d0c7e5f RAILS_ENV=test bin/rails runner script/seed_sharing_demo.rb",
    { encoding: "utf-8" }
  )
  const match = output.match(/SEED_COMPLETE:conn_id=(\d+):mix_id=(\d+)/)
  if (!match) throw new Error(`Failed to seed sharing demo: ${output}`)
  return { connectionId: match[1], mixId: match[2] }
}

test.describe("track sharing and notification visual verification", () => {
  let seeded

  test.beforeEach(async () => {
    seeded = seedSharingData()
  })

  test("captures desktop and mobile screenshots of sharing and notification hub", async ({ page }, testInfo) => {
    test.setTimeout(60000)
    if (testInfo.project.name !== "chromium") return

    const screenshotsDir = path.resolve("docs/screenshots")
    if (!fs.existsSync(screenshotsDir)) {
      fs.mkdirSync(screenshotsDir, { recursive: true })
    }

    // 1. Desktop Viewport (1440x900)
    await page.setViewportSize({ width: 1440, height: 900 })
    await signInAs(page)
    await page.goto("/server_connections")
    await page.waitForSelector(".redesign-topbar")

    // Verify Notification Bell has unread badge
    const badge = page.locator("#notifications_badge")
    await expect(badge).toBeVisible()
    await expect(badge).toContainText("2")

    // Open Notification Hub dropdown
    const notifToggle = page.locator(".redesign-notification-hub__toggle")
    await notifToggle.click()
    await page.waitForSelector(".redesign-notification-hub__panel:not([hidden])")
    await page.waitForTimeout(400)

    // Capture Notification Hub on Desktop
    await page.screenshot({ path: path.join(screenshotsDir, "notification-hub-desktop-1440.png") })

    // Close Notification Hub
    await notifToggle.click()
    await page.waitForTimeout(200)

    // Open Share Dialog by dispatching the custom event on the page
    await page.evaluate(() => {
      window.dispatchEvent(new CustomEvent("sonzra:open-share", {
        detail: {
          itemId: "track-m83",
          title: "Midnight City",
          artist: "M83",
          album: "Hurry Up, We're Dreaming",
          artworkUrl: "/brand/sonzra-mark.svg",
          mediaServerId: 1
        }
      }))
    })

    const shareDialog = page.locator("#share-dialog")
    await expect(shareDialog).toBeVisible()
    await page.fill(".redesign-share-dialog__textarea", "Check out this incredible synth intro!")
    await page.waitForTimeout(400)

    // Capture Share Dialog on Desktop
    await page.screenshot({ path: path.join(screenshotsDir, "share-dialog-desktop-1440.png") })

    // Close share dialog
    await page.locator(".redesign-share-dialog__close").click()
    await expect(shareDialog).not.toBeVisible()

    // 2. Mobile Viewport (390x844 - iPhone 14 / modern mobile)
    await page.setViewportSize({ width: 390, height: 844 })
    await page.waitForTimeout(300)

    // Open Share Dialog on Mobile
    await page.evaluate(() => {
      window.dispatchEvent(new CustomEvent("sonzra:open-share", {
        detail: {
          itemId: "track-m83",
          title: "Midnight City",
          artist: "M83",
          album: "Hurry Up, We're Dreaming",
          artworkUrl: "/brand/sonzra-mark.svg",
          mediaServerId: 1
        }
      }))
    })
    await expect(shareDialog).toBeVisible()
    await page.waitForTimeout(400)

    // Capture Mobile Bottom Sheet Share Dialog
    await page.screenshot({ path: path.join(screenshotsDir, "share-dialog-mobile-390.png") })

    await page.locator(".redesign-share-dialog__close").click()
    await expect(shareDialog).not.toBeVisible()

    // Mobile Notifications Page View
    await page.goto("/notifications")
    await page.locator("main .redesign-notification-card").first().waitFor({ state: "visible" })
    await page.waitForTimeout(400)

    // Capture Mobile Notifications Feed
    await page.screenshot({ path: path.join(screenshotsDir, "notifications-page-mobile-390.png") })

    // Mobile Hamburger Menu with Notifications item & badge
    await page.goto("/server_connections")
    await page.waitForSelector(".redesign-topbar__menu-toggle")
    await page.locator(".redesign-topbar__menu-toggle").click()
    await page.waitForTimeout(400)
    await page.screenshot({ path: path.join(screenshotsDir, "mobile-navigation-notifications-390.png") })
  })
})
