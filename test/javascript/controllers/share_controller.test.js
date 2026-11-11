import { Application } from "@hotwired/stimulus"
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import ShareController from "../../../app/javascript/controllers/share_controller.js"

describe("share controller", () => {
  let application
  let controller
  let fetchMock

  beforeEach(async () => {
    HTMLDialogElement.prototype.showModal = function showModal() {
      this.open = true
    }
    HTMLDialogElement.prototype.close = function close() {
      this.open = false
    }

    fetchMock = vi.fn(async (url, options = {}) => {
      if (options.method === "POST" && url === "/track_shares") {
        return {
          ok: true,
          status: 201,
          json: async () => ({ id: "share-1", success: true })
        }
      }
      return { ok: true, json: async () => [] }
    })
    vi.stubGlobal("fetch", fetchMock)

    const metaCsrf = document.createElement("meta")
    metaCsrf.name = "csrf-token"
    metaCsrf.content = "mock-csrf-token"
    document.head.appendChild(metaCsrf)

    document.body.innerHTML = `
      <div id="player-feedback" hidden></div>
      <dialog id="share-dialog" class="redesign-share-dialog" data-controller="share" data-share-target="dialog" data-action="click->share#closeOnBackdrop">
        <div class="redesign-share-dialog__panel">
          <div class="redesign-share-dialog__heading">
            <h2 id="share-dialog-title">Recommend track</h2>
            <button type="button" class="redesign-share-dialog__close" data-action="share#close">Close</button>
          </div>
          <div class="redesign-share-dialog__preview">
            <img class="redesign-share-dialog__art" data-share-target="previewArt" src="" alt="" hidden>
            <div class="redesign-share-dialog__meta">
              <strong class="redesign-share-dialog__title" data-share-target="previewTitle">Unknown Title</strong>
              <span class="redesign-share-dialog__artist" data-share-target="previewArtist">Unknown Artist</span>
            </div>
          </div>
          <form class="redesign-share-dialog__form" data-share-target="form" data-action="submit->share#submit">
            <select data-share-target="recipientSelect" required>
              <option value="" disabled selected>Select a listener</option>
              <option value="2">alice@example.com</option>
              <option value="3">bob@example.com</option>
            </select>
            <span data-share-target="charCount">280</span>
            <textarea data-share-target="noteInput" data-action="input->share#updateCharCount" maxlength="280"></textarea>
            <p data-share-target="errorFeedback" hidden></p>
            <button type="button" class="cancel-button" data-action="share#close">Cancel</button>
            <button type="submit" data-share-target="submitButton">Send recommendation</button>
          </form>
        </div>
      </dialog>
    `

    application = Application.start()
    application.register("share", ShareController)
    await new Promise((resolve) => setTimeout(resolve, 10))
    controller = application.getControllerForElementAndIdentifier(document.getElementById("share-dialog"), "share")
  })

  afterEach(() => {
    application.stop()
    vi.restoreAllMocks()
    document.head.innerHTML = ""
    document.body.innerHTML = ""
  })

  it("opens modal and populates track metadata on sonzra:open-share event", () => {
    const dialog = document.getElementById("share-dialog")
    expect(dialog.open).toBeFalsy()

    window.dispatchEvent(new CustomEvent("sonzra:open-share", {
      bubbles: true,
      detail: {
        itemId: "track-123",
        title: "Solaris",
        artist: "Photay",
        album: "Onism",
        artworkUrl: "/art/track-123.jpg",
        mediaServerId: "srv-1"
      }
    }))

    expect(dialog.open).toBe(true)
    expect(controller.previewTitleTarget.textContent).toBe("Solaris")
    expect(controller.previewArtistTarget.textContent).toBe("Photay")
    expect(controller.previewArtTarget.src).toContain("/art/track-123.jpg")
    expect(controller.previewArtTarget.hidden).toBe(false)
    expect(controller.noteInputTarget.value).toBe("")
    expect(controller.charCountTarget.textContent).toBe("280")
    expect(controller.errorFeedbackTarget.hidden).toBe(true)
    expect(controller.submitButtonTarget.disabled).toBe(false)
  })

  it("updates live character counter as user types into note field", () => {
    controller.noteInputTarget.value = "Check out this guitar solo!"
    controller.updateCharCount()
    expect(controller.charCountTarget.textContent).toBe(String(280 - 27))

    controller.noteInputTarget.value = "a".repeat(280)
    controller.updateCharCount()
    expect(controller.charCountTarget.textContent).toBe("0")
  })

  it("closes the dialog when close() is invoked", () => {
    controller.openForTrack({ title: "Track", artist: "Artist" })
    expect(controller.dialogTarget.open).toBe(true)

    controller.close()
    expect(controller.dialogTarget.open).toBe(false)
  })

  it("closes dialog on backdrop click and ignores clicks inside dialog panel", () => {
    controller.openForTrack({ title: "Track", artist: "Artist" })
    expect(controller.dialogTarget.open).toBe(true)

    const panel = document.querySelector(".redesign-share-dialog__panel")
    controller.closeOnBackdrop({ target: panel })
    expect(controller.dialogTarget.open).toBe(true)

    controller.closeOnBackdrop({ target: controller.dialogTarget })
    expect(controller.dialogTarget.open).toBe(false)
  })

  it("closes dialog when Escape key is pressed", () => {
    controller.openForTrack({ title: "Track", artist: "Artist" })
    expect(controller.dialogTarget.open).toBe(true)

    window.dispatchEvent(new KeyboardEvent("keydown", { key: "Escape" }))
    expect(controller.dialogTarget.open).toBe(false)
  })

  it("submits recommendation to /track_shares and shows feedback toast on success", async () => {
    controller.openForTrack({
      itemId: "item-999",
      title: "Night Drive",
      artist: "Timecop1983",
      album: "Night Drive Album",
      artworkUrl: "/covers/nightdrive.jpg",
      mediaServerId: "srv-2"
    })

    controller.recipientSelectTarget.value = "2"
    controller.noteInputTarget.value = "Loved this synthwave track!"

    await controller.submit(new Event("submit"))

    expect(fetchMock).toHaveBeenCalledWith("/track_shares", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Accept: "application/json",
        "X-CSRF-Token": "mock-csrf-token"
      },
      body: JSON.stringify({
        recipient_id: "2",
        item_id: "item-999",
        title: "Night Drive",
        artist: "Timecop1983",
        album: "Night Drive Album",
        media_server_id: "srv-2",
        artwork_item_id: "/covers/nightdrive.jpg",
        note: "Loved this synthwave track!"
      })
    })

    expect(controller.dialogTarget.open).toBe(false)
    const feedbackEl = document.getElementById("player-feedback")
    expect(feedbackEl.textContent).toBe("Track shared with alice@example.com")
    expect(feedbackEl.hidden).toBe(false)
  })

  it("shows error feedback and leaves dialog open when server responds with an error", async () => {
    fetchMock.mockResolvedValueOnce({
      ok: false,
      status: 422,
      json: async () => ({ error: "Recipient cannot be yourself" })
    })

    controller.openForTrack({
      itemId: "item-999",
      title: "Night Drive",
      artist: "Timecop1983"
    })
    controller.recipientSelectTarget.value = "2"

    await controller.submit(new Event("submit"))

    expect(controller.dialogTarget.open).toBe(true)
    expect(controller.errorFeedbackTarget.hidden).toBe(false)
    expect(controller.errorFeedbackTarget.textContent).toBe("Recipient cannot be yourself")
    expect(controller.submitButtonTarget.disabled).toBe(false)
  })

  it("shows fallback error message when network request fails completely", async () => {
    fetchMock.mockRejectedValueOnce(new Error("Network connection lost"))

    controller.openForTrack({
      itemId: "item-999",
      title: "Night Drive",
      artist: "Timecop1983"
    })
    controller.recipientSelectTarget.value = "2"

    await controller.submit(new Event("submit"))

    expect(controller.dialogTarget.open).toBe(true)
    expect(controller.errorFeedbackTarget.hidden).toBe(false)
    expect(controller.errorFeedbackTarget.textContent).toBe("Network connection lost")
    expect(controller.submitButtonTarget.disabled).toBe(false)
  })

  it("does not submit if no recipient is selected", async () => {
    controller.openForTrack({
      itemId: "item-999",
      title: "Night Drive",
      artist: "Timecop1983"
    })
    controller.recipientSelectTarget.value = ""

    await controller.submit(new Event("submit"))

    expect(fetchMock).not.toHaveBeenCalled()
    expect(controller.dialogTarget.open).toBe(true)
  })
})
