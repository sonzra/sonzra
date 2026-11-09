import { expect, test } from "@playwright/test"
import { signInAs } from "./support/helpers.js"
import path from "node:path"

const scratchDir = "/root/.gemini/antigravity-cli/brain/ce17afe7-e544-4bcd-804e-1cae1da9f698/scratch"

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

    const isMobile = testInfo.project.name.includes("mobile")
    const screenshotPath = path.join(scratchDir, isMobile ? "downloads-offline-mobile.png" : "downloads-offline-desktop.png")
    await page.screenshot({ path: screenshotPath, fullPage: true })
  })
})
