import { expect, test } from "@playwright/test"
import { seedTestLibrary, signInAs } from "./support/helpers.js"
import fs from "node:fs"
import path from "node:path"

test.describe("Queue clear confirmation modal", () => {
  test.beforeEach(async () => {
    seedTestLibrary()
  })

  test("opens, restyles, and closes queue clear confirmation across viewports", async ({ page }, testInfo) => {
    if (testInfo.project.name !== "chromium") return

    const screenshotDir = process.env.SCREENSHOT_DIR || "/root/.gemini/antigravity-cli/brain/42f58650-8b9f-4bd9-b7ff-1e85490812d1/screenshots"
    fs.mkdirSync(screenshotDir, { recursive: true })

    await signInAs(page)
    await page.waitForSelector(".redesign-topbar")

    // Desktop Viewport (1440x900)
    await page.setViewportSize({ width: 1440, height: 900 })
    await page.waitForTimeout(300)

    // Reveal player shell and queue panel
    await page.evaluate(() => {
      const shell = document.querySelector("[data-player-target='shell']")
      if (shell) shell.hidden = false
      const queue = document.querySelector("#player-queue")
      if (queue) queue.hidden = false
    })

    const clearTrigger = page.locator(".listen-queue__clear")
    await expect(clearTrigger).toBeAttached()
    await clearTrigger.dispatchEvent("click")

    const dialog = page.locator("dialog.listen-queue__confirm")
    await expect(dialog).toBeVisible()
    await expect(dialog).toHaveAttribute("open", "")
    await expect(dialog.locator(".redesign-dialog__eyebrow")).toHaveText("Clear queue")
    await expect(dialog.locator(".redesign-dialog__title")).toHaveText("Stop playback and remove every queued track?")
    await expect(dialog.locator(".danger-button")).toHaveText("Clear queue")
    await expect(dialog.locator(".secondary-button")).toHaveText("Cancel")

    // Save desktop screenshot
    await page.screenshot({ path: path.join(screenshotDir, "queue-modal-desktop.png") })

    // Cancel prompt
    const cancelButton = dialog.locator(".listen-queue__confirm-cancel")
    await cancelButton.click()
    await expect(dialog).not.toHaveAttribute("open", "")

    // Mobile Viewport (390x844)
    await page.setViewportSize({ width: 390, height: 844 })
    await page.waitForTimeout(300)

    await clearTrigger.dispatchEvent("click")
    await expect(dialog).toBeVisible()
    await expect(dialog).toHaveAttribute("open", "")

    // Save mobile screenshot
    await page.screenshot({ path: path.join(screenshotDir, "queue-modal-mobile.png") })

    // Close via 'X' button
    const closeBtn = dialog.locator(".redesign-dialog__close")
    await closeBtn.click()
    await expect(dialog).not.toHaveAttribute("open", "")
  })
})
