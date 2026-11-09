import { expect, test } from "@playwright/test"
import { signInAs } from "./support/helpers.js"
import fs from "node:fs"
import path from "node:path"

test.describe("offline recovery UI", () => {
  test("shows the recovery banner on downloads page when offline with 0 downloads", async ({ page }, testInfo) => {
    await signInAs(page)

    // Simulate server / VPN disconnect
    await page.route("**/up", (route) => route.abort())

    await page.goto("/offline_shell")

    const emptySection = page.locator("[data-offline-library-target='empty']")
    await expect(emptySection).toBeVisible()

    const recoveryCard = page.locator(".offline-downloads__recovery")
    await expect(recoveryCard).toBeVisible()

    const retryButton = page.locator(".offline-downloads__retry-button")
    await expect(retryButton).toBeVisible()
    await expect(retryButton).toContainText("Retry connection")

    const scratchDir = process.env.SCREENSHOT_DIR
    if (scratchDir && fs.existsSync(scratchDir)) {
      const isMobile = testInfo.project.name.includes("mobile")
      const screenshotPath = path.join(scratchDir, isMobile ? "downloads-offline-mobile.png" : "downloads-offline-desktop.png")
      await page.screenshot({ path: screenshotPath, fullPage: true })
    }
  })
})
