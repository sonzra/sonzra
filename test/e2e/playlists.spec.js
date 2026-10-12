import { expect, test } from "@playwright/test"
import { cleanTestLibrary, seedTestLibrary, signInAs } from "./support/helpers.js"

test.describe("Playlists addition flow", () => {
  let seeded

  test.beforeAll(() => {
    seeded = seedTestLibrary()
  })

  test("adds a single track from a mix to a playlist with mocked server response", async ({ page }) => {
    // Intercept playlist API requests in browser so no real Jellyfin connection is needed
    await page.route(`**/server_connections/${seeded.connectionId}/playlists`, async (route) => {
      if (route.request().method() === "GET") {
        await route.fulfill({
          status: 200,
          contentType: "application/json",
          body: JSON.stringify([
            { Id: "playlist-101", Name: "Late Night Beats" }
          ])
        })
      } else {
        await route.continue()
      }
    })

    let addedToPlaylistCalled = false
    await page.route(`**/server_connections/${seeded.connectionId}/playlists/playlist-101/items`, async (route) => {
      expect(route.request().method()).toBe("POST")
      const postData = JSON.parse(route.request().postData() || "{}")
      expect(postData.item_id).toBe("e2e-track-1")
      expect(postData.item_type).toBe("Audio")
      addedToPlaylistCalled = true

      await route.fulfill({
        status: 204,
        contentType: "application/json",
        body: ""
      })
    })

    // Sign in and navigate to the mix detail page
    await signInAs(page)
    await page.goto(`/recommendation_collections/${seeded.mixId}`)

    await expect(page.locator(".detail-hero h1")).toContainText("Weekend Discovery")
    await expect(page.locator(".track-list strong")).toContainText("Starlight Echoes")

    // Click "Add to playlist" on the track row
    // In classic layout: button with aria-label="Add Starlight Echoes to playlist"
    // In redesign layout: overflow menu -> "Add to playlist"
    const classicBtn = page.locator("button[aria-label='Add Starlight Echoes to playlist']")
    const redesignMenuToggle = page.locator("button[aria-label='More actions for Starlight Echoes']")

    if (await redesignMenuToggle.isVisible()) {
      await redesignMenuToggle.click()
      const menuAddBtn = page.locator(".detail-track__menu-panel button", { hasText: "Add to playlist" })
      await expect(menuAddBtn).toBeVisible()
      await menuAddBtn.click()
    } else {
      await expect(classicBtn).toBeVisible()
      await classicBtn.click()
    }

    // Modal dialog opens
    const dialog = page.locator("dialog.playlist-picker")
    await expect(dialog).toBeVisible()

    // Playlist choice is rendered from mock
    const playlistChoice = dialog.locator(".playlist-picker__choice", { hasText: "Late Night Beats" })
    await expect(playlistChoice).toBeVisible()

    // Take screenshot with modal dialog open
    await page.screenshot({ path: "test-results/playlist-modal-track.png" })

    // Click the playlist
    await playlistChoice.click()

    // Dialog closes
    await expect(dialog).not.toBeVisible()

    // Feedback toast appears confirming track was added
    const feedback = page.locator("#player-feedback")
    await expect(feedback).toBeVisible()
    await expect(feedback).toContainText("Track added to playlist")

    expect(addedToPlaylistCalled).toBe(true)
  })

  test("creates a new playlist from a mix detail header with mocked server response", async ({ page }) => {
    let createPlaylistCalled = false
    await page.route(`**/server_connections/${seeded.connectionId}/playlists`, async (route) => {
      if (route.request().method() === "GET") {
        await route.fulfill({
          status: 200,
          contentType: "application/json",
          body: JSON.stringify([])
        })
      } else if (route.request().method() === "POST") {
        const postData = JSON.parse(route.request().postData() || "{}")
        expect(postData.name).toBe("Weekend Discovery")
        expect(postData.item_id).toBe(seeded.mixId)
        expect(postData.item_type).toBe("RecommendationCollection")
        createPlaylistCalled = true

        await route.fulfill({
          status: 201,
          contentType: "application/json",
          body: JSON.stringify({ id: "new-playlist-202", item_included: false })
        })
      } else {
        await route.continue()
      }
    })

    await page.route(`**/server_connections/${seeded.connectionId}/playlists/new-playlist-202/items`, async (route) => {
      await route.fulfill({
        status: 204,
        contentType: "application/json",
        body: ""
      })
    })

    await signInAs(page)
    await page.goto(`/recommendation_collections/${seeded.mixId}`)

    // Click "Add to playlist" in the hero header
    const heroPlaylistBtn = page.locator("button[aria-label='Add Weekend Discovery to playlist']")
    await expect(heroPlaylistBtn).toBeVisible()
    await heroPlaylistBtn.click()

    const dialog = page.locator("dialog.playlist-picker")
    await expect(dialog).toBeVisible()

    // Pre-filled playlist name should match collection title
    const nameInput = dialog.locator("input[data-card-options-target='playlistName']")
    await expect(nameInput).toHaveValue("Weekend Discovery")

    // Take screenshot with create playlist dialog open and pre-filled
    await page.screenshot({ path: "test-results/playlist-modal-create.png" })

    // Submit form to create playlist
    await dialog.locator("form.playlist-picker__create button[type='submit']").click()

    // Dialog closes
    await expect(dialog).not.toBeVisible()

    // Feedback toast confirms creation
    const feedback = page.locator("#player-feedback")
    await expect(feedback).toBeVisible()
    await expect(feedback).toContainText("Playlist created and mix added")

    expect(createPlaylistCalled).toBe(true)
  })
})
