import { Application } from "@hotwired/stimulus"
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import CollaborativePlaylistController from "../../app/javascript/controllers/collaborative_playlist_controller.js"

describe("collaborative playlist controller", () => {
  let application

  beforeEach(async () => {
    // Mock HTMLDialogElement methods in JSDOM
    if (!HTMLDialogElement.prototype.showModal) {
      HTMLDialogElement.prototype.showModal = function() {
        this.open = true
      }
    }
    if (!HTMLDialogElement.prototype.close) {
      HTMLDialogElement.prototype.close = function() {
        this.open = false
      }
    }

    document.body.innerHTML = `
      <div data-controller="collaborative-playlist"
           data-collaborative-playlist-playlist-id-value="playlist-1"
           data-collaborative-playlist-playlist-name-value="Summer Vibes"
           data-collaborative-playlist-server-connection-id-value="10"
           data-collaborative-playlist-url-value="/server_connections/10/playlists/playlist-1/collaborators">
        <button data-action="click->collaborative-playlist#openDialog" id="open-btn">Share</button>
        <dialog data-collaborative-playlist-target="dialog">
          <button data-action="click->collaborative-playlist#closeDialog" id="close-btn">Close</button>
          <ul data-collaborative-playlist-target="list"></ul>
          <p data-collaborative-playlist-target="empty" hidden></p>
          <p data-collaborative-playlist-target="feedback"></p>
        </dialog>
      </div>
    `

    application = Application.start()
    application.register("collaborative-playlist", CollaborativePlaylistController)
    await Promise.resolve()
  })

  afterEach(() => {
    application?.stop()
    vi.restoreAllMocks()
  })

  it("opens dialog and loads collaborator list", async () => {
    const mockConnections = [
      { id: 20, username: "collab", email: "collab@example.com", display_name: "collab", is_collaborator: false },
      { id: 21, username: "friend", email: "friend@example.com", display_name: "friend", is_collaborator: true }
    ]

    globalThis.fetch = vi.fn().mockResolvedValue({
      ok: true,
      json: async () => ({ fellow_connections: mockConnections })
    })

    const openBtn = document.getElementById("open-btn")
    const dialog = document.querySelector("dialog")

    expect(dialog.open).toBeFalsy()
    openBtn.click()
    expect(dialog.open).toBe(true)

    // Wait for async fetch to populate list
    await vi.waitFor(() => {
      const items = document.querySelectorAll(".redesign-share-playlist-dialog__item")
      expect(items.length).toBe(2)
    })

    const buttons = document.querySelectorAll(".redesign-share-playlist-dialog__action-button")
    expect(buttons[0].textContent.trim()).toBe("Share")
    expect(buttons[1].textContent.trim()).toBe("Remove")
  })

  it("closes dialog when close button is clicked", () => {
    const dialog = document.querySelector("dialog")
    const closeBtn = document.getElementById("close-btn")

    dialog.showModal()
    expect(dialog.open).toBe(true)

    closeBtn.click()
    expect(dialog.open).toBe(false)
  })

  it("handles sharing toggle action", async () => {
    globalThis.fetch = vi.fn()
      // First fetch: load list
      .mockResolvedValueOnce({
        ok: true,
        json: async () => ({
          fellow_connections: [
            { id: 20, username: "collab", email: "collab@example.com", display_name: "collab", is_collaborator: false }
          ]
        })
      })
      // Second fetch: POST share
      .mockResolvedValueOnce({
        ok: true,
        json: async () => ({ success: true })
      })

    document.getElementById("open-btn").click()

    await vi.waitFor(() => {
      expect(document.querySelector(".redesign-share-playlist-dialog__action-button")).not.toBeNull()
    })

    const actionBtn = document.querySelector(".redesign-share-playlist-dialog__action-button")
    expect(actionBtn.textContent.trim()).toBe("Share")

    actionBtn.click()

    await vi.waitFor(() => {
      expect(actionBtn.textContent.trim()).toBe("Remove")
    })

    const feedback = document.querySelector("p[data-collaborative-playlist-target='feedback']")
    expect(feedback.textContent).toBe("Playlist shared successfully.")
  })
})
