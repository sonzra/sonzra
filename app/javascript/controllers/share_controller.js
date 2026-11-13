import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "dialog", "form", "recipientSelect", "noteInput",
    "charCount", "previewTitle", "previewArtist", "previewArt",
    "submitButton", "errorFeedback"
  ]
  static values = {
    usersUrl: { type: String, default: "/admin/users.json" }
  }

  connect() {
    this.boundHandleOpen = this.handleOpenEvent.bind(this)
    this.boundHandleKeyDown = this.handleKeyDown.bind(this)
    window.addEventListener("sonzra:open-share", this.boundHandleOpen)
    window.addEventListener("keydown", this.boundHandleKeyDown)
  }

  disconnect() {
    window.removeEventListener("sonzra:open-share", this.boundHandleOpen)
    window.removeEventListener("keydown", this.boundHandleKeyDown)
  }

  handleOpenEvent(event) {
    this.openForTrack(event.detail || {})
  }

  handleKeyDown(event) {
    if (event.key === "Escape" && this.isOpen()) {
      event.preventDefault()
      this.close()
    }
  }

  isOpen() {
    if (!this.hasDialogTarget) return false
    return Boolean(this.dialogTarget.open || this.dialogTarget.hasAttribute("open"))
  }

  openForTrack({ itemId, title, artist, album, artworkUrl, mediaServerId, serverConnectionId } = {}) {
    this.trackData = {
      itemId,
      title,
      artist,
      album,
      artworkUrl,
      mediaServerId,
      serverConnectionId: serverConnectionId || mediaServerId
    }
    if (this.hasPreviewTitleTarget) {
      this.previewTitleTarget.textContent = title || "Unknown Title"
    }
    if (this.hasPreviewArtistTarget) {
      this.previewArtistTarget.textContent = artist || "Unknown Artist"
    }
    if (this.hasPreviewArtTarget) {
      if (artworkUrl) {
        this.previewArtTarget.src = artworkUrl
        this.previewArtTarget.hidden = false
      } else {
        this.previewArtTarget.hidden = true
      }
    }
    if (this.hasNoteInputTarget) {
      this.noteInputTarget.value = ""
    }
    this.updateCharCount()
    if (this.hasErrorFeedbackTarget) {
      this.errorFeedbackTarget.textContent = ""
      this.errorFeedbackTarget.hidden = true
    }
    if (this.hasSubmitButtonTarget) {
      this.submitButtonTarget.disabled = false
    }
    if (this.hasDialogTarget) {
      if (typeof this.dialogTarget.showModal === "function") {
        this.dialogTarget.showModal()
      } else {
        this.dialogTarget.setAttribute("open", "")
      }
    }
  }

  updateCharCount() {
    if (!this.hasCharCountTarget) return
    const length = this.hasNoteInputTarget ? (this.noteInputTarget.value?.length || 0) : 0
    const remaining = 280 - length
    this.charCountTarget.textContent = remaining
  }

  async submit(event) {
    event.preventDefault()
    if (!this.hasRecipientSelectTarget) return
    const recipientId = this.recipientSelectTarget.value
    if (!recipientId) return

    if (this.hasSubmitButtonTarget) this.submitButtonTarget.disabled = true
    if (this.hasErrorFeedbackTarget) {
      this.errorFeedbackTarget.hidden = true
      this.errorFeedbackTarget.textContent = ""
    }

    try {
      const response = await fetch("/track_shares", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Accept: "application/json",
          "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content || ""
        },
        body: JSON.stringify({
          recipient_id: recipientId,
          item_id: this.trackData?.itemId,
          title: this.trackData?.title,
          artist: this.trackData?.artist,
          album: this.trackData?.album,
          media_server_id: this.trackData?.mediaServerId,
          server_connection_id: this.trackData?.serverConnectionId || this.trackData?.mediaServerId,
          artwork_item_id: this.trackData?.artworkUrl,
          note: this.hasNoteInputTarget ? this.noteInputTarget.value : ""
        })
      })

      if (!response.ok) {
        const errorData = await response.json().catch(() => ({}))
        throw new Error(errorData.error || errorData.message || "Failed to share track")
      }

      const selectedOption = this.recipientSelectTarget.selectedOptions?.[0]
      const recipientName = selectedOption?.text || "listener"
      this.close()
      this.showToast(`Track shared with ${recipientName}`)
    } catch (err) {
      if (this.hasErrorFeedbackTarget) {
        this.errorFeedbackTarget.textContent = err.message || "Failed to share track"
        this.errorFeedbackTarget.hidden = false
      }
      if (this.hasSubmitButtonTarget) this.submitButtonTarget.disabled = false
    }
  }

  showToast(message) {
    const playerEl = document.querySelector("[data-controller~='player']")
    if (playerEl && this.application) {
      const player = this.application.getControllerForElementAndIdentifier(playerEl, "player")
      if (player?.showFeedback) {
        player.showFeedback(message)
        return
      }
    }
    const feedbackEl = document.getElementById("player-feedback")
    if (feedbackEl) {
      feedbackEl.textContent = message
      feedbackEl.hidden = false
      feedbackEl.classList.add("is-visible")
      window.setTimeout(() => {
        feedbackEl.classList.remove("is-visible")
        feedbackEl.hidden = true
      }, 3000)
    }
  }

  close() {
    if (!this.hasDialogTarget) return
    if (typeof this.dialogTarget.close === "function" && this.dialogTarget.open) {
      this.dialogTarget.close()
    } else {
      this.dialogTarget.removeAttribute("open")
    }
  }

  closeOnBackdrop(event) {
    if (event.target === this.dialogTarget) {
      this.close()
    }
  }
}
