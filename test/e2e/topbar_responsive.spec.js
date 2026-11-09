import { expect, test } from "@playwright/test"
import { signInAs, seedTestLibrary } from "./support/helpers.js"
import fs from "node:fs"
import path from "node:path"

test.describe("responsive topbar navigation", () => {
  test.beforeEach(async () => {
    seedTestLibrary()
  })

  test("maintains visibility, accessibility, and zero overflow across viewports", async ({ page }, testInfo) => {
    if (testInfo.project.name !== "chromium") return

    await signInAs(page)
    await page.waitForSelector(".redesign-topbar")

    const screenshotDir = process.env.SCREENSHOT_DIR
    const saveScreenshot = async (filename, locator = null) => {
      if (!screenshotDir || !fs.existsSync(screenshotDir)) return
      const p = path.join(screenshotDir, filename)
      if (locator) {
        await locator.screenshot({ path: p })
      } else {
        await page.screenshot({ path: p })
      }
    }

    // 1. Tablet Portrait Viewport (768x1024 - iPad Portrait)
    await page.setViewportSize({ width: 768, height: 1024 })
    await page.waitForTimeout(300)

    // Verify zero horizontal page scrolling
    const bodyScrollWidth = await page.evaluate(() => document.body.scrollWidth)
    expect(bodyScrollWidth).toBeLessThanOrEqual(768)

    // Verify search trigger is visible and within bounds
    const searchTrigger = page.locator(".redesign-search-trigger")
    await expect(searchTrigger).toBeVisible()
    const searchBox = await searchTrigger.boundingBox()
    expect(searchBox).not.toBeNull()
    expect(searchBox.x + searchBox.width).toBeLessThanOrEqual(768)

    // Verify keyboard shortcut badge is hidden on tablet
    const kbdBadge = searchTrigger.locator("kbd")
    await expect(kbdBadge).toBeHidden()

    // Verify profile menu toggle is visible within the viewport
    const profileToggle = page.locator(".redesign-profile__toggle")
    await expect(profileToggle).toBeVisible()
    const profileBox = await profileToggle.boundingBox()
    expect(profileBox).not.toBeNull()
    expect(profileBox.x + profileBox.width).toBeLessThanOrEqual(768)

    // Save tablet screenshots if directory configured
    await saveScreenshot("tablet-topbar-768.png")
    const topbar = page.locator(".redesign-topbar")
    await saveScreenshot("tablet-topbar-768-detail.png", topbar)

    // Verify clicking search opens dialog
    await searchTrigger.click()
    const searchDialog = page.locator(".redesign-search-dialog")
    await expect(searchDialog).toBeVisible()
    await saveScreenshot("tablet-search-open-768.png")
    await page.keyboard.press("Escape")
    await expect(searchDialog).not.toBeVisible()

    // 2. Small Desktop Viewport (1024x768 - iPad Landscape)
    await page.setViewportSize({ width: 1024, height: 768 })
    await page.waitForTimeout(300)

    // Verify zero overlap between primary nav and search trigger at 1024px
    const primaryNav = page.locator(".redesign-topbar__primary")
    const primaryBox = await primaryNav.boundingBox()
    const searchBox1024 = await searchTrigger.boundingBox()
    expect(primaryBox.x + primaryBox.width).toBeLessThan(searchBox1024.x)

    await saveScreenshot("midsized-topbar-1024.png")

    // 3. Desktop Baseline Viewport (1440x900)
    await page.setViewportSize({ width: 1440, height: 900 })
    await page.waitForTimeout(300)

    await expect(searchTrigger).toBeVisible()
    await expect(profileToggle).toBeVisible()
    await expect(page.locator(".redesign-server-pill")).toBeVisible()
    await saveScreenshot("desktop-topbar-1440.png")

    // 4. Mobile Viewport (390x844)
    await page.setViewportSize({ width: 390, height: 844 })
    await page.waitForTimeout(300)
    await expect(page.locator(".redesign-topbar__menu-toggle")).toBeVisible()
    await saveScreenshot("mobile-topbar-390.png")
  })
})
