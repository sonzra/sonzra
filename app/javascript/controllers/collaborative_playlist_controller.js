import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog", "list", "empty", "feedback"]
  static values = {
    playlistId: String,
    playlistName: String,
    serverConnectionId: Number,
    url: String
  }

  connect() {
    if (this.hasDialogTarget) {
      this.dialogTarget.addEventListener("click", (event) => {
        if (event.target === this.dialogTarget) {
          this.closeDialog()
        }
      })
    }
  }

  async openDialog() {
    if (!this.hasDialogTarget) return
    this.dialogTarget.showModal()
    this.clearFeedback()
    await this.loadCollaborators()
  }

  closeDialog() {
    if (this.hasDialogTarget && this.dialogTarget.open) {
      this.dialogTarget.close()
    }
  }

  async loadCollaborators() {
    if (!this.hasListTarget) return
    this.listTarget.innerHTML = `<li class="redesign-share-playlist-dialog__loading">Loading listeners…</li>`
    if (this.hasEmptyTarget) this.emptyTarget.hidden = true

    try {
      const response = await fetch(this.urlValue, {
        headers: { "Accept": "application/json" }
      })

      if (!response.ok) {
        throw new Error("Failed to load collaborators")
      }

      const data = await response.json()
      const connections = data.fellow_connections || []

      if (connections.length === 0) {
        this.listTarget.innerHTML = ""
        if (this.hasEmptyTarget) this.emptyTarget.hidden = false
        return
      }

      this.renderCollaborators(connections)
    } catch (error) {
      this.listTarget.innerHTML = `<li class="redesign-share-playlist-dialog__error">Could not load listeners: ${error.message}</li>`
    }
  }

  renderCollaborators(connections) {
    this.listTarget.innerHTML = connections.map((conn) => {
      const actionText = conn.is_collaborator ? "Remove" : "Share"
      const actionClass = conn.is_collaborator ? "is-danger" : "primary-button"
      const roleText = conn.is_collaborator ? "Collaborator" : "Not shared"

      return `
        <li class="redesign-share-playlist-dialog__item" data-connection-id="${conn.id}">
          <div class="redesign-share-playlist-dialog__user-info">
            <span class="redesign-share-playlist-dialog__avatar">${this.escape(conn.display_name.charAt(0).toUpperCase())}</span>
            <div>
              <strong>${this.escape(conn.display_name)}</strong>
              <small>${this.escape(roleText)}</small>
            </div>
          </div>
          <button type="button"
                  class="redesign-share-playlist-dialog__action-button ${actionClass}"
                  data-action="click->collaborative-playlist#toggleShare"
                  data-connection-id="${conn.id}"
                  data-is-collaborator="${conn.is_collaborator}">
            ${actionText}
          </button>
        </li>
      `
    }).join("")
  }

  async toggleShare(event) {
    const button = event.currentTarget
    const connectionId = button.dataset.connectionId
    const isCollaborator = button.dataset.isCollaborator === "true"
    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.getAttribute("content")

    button.disabled = true
    const originalText = button.textContent

    try {
      let response
      if (isCollaborator) {
        response = await fetch(`/server_connections/${this.serverConnectionIdValue}/playlists/${this.playlistIdValue}/collaborators/${connectionId}`, {
          method: "DELETE",
          headers: {
            "Accept": "application/json",
            "X-CSRF-Token": csrfToken
          }
        })
      } else {
        response = await fetch(`/server_connections/${this.serverConnectionIdValue}/playlists/${this.playlistIdValue}/collaborators`, {
          method: "POST",
          headers: {
            "Content-Type": "application/json",
            "Accept": "application/json",
            "X-CSRF-Token": csrfToken
          },
          body: JSON.stringify({
            target_connection_id: connectionId,
            playlist_name: this.playlistNameValue
          })
        })
      }

      const result = await response.json()
      if (!response.ok) {
        throw new Error(result.error || "Action failed")
      }

      const newIsCollaborator = !isCollaborator
      button.dataset.isCollaborator = newIsCollaborator ? "true" : "false"
      button.textContent = newIsCollaborator ? "Remove" : "Share"
      button.className = `redesign-share-playlist-dialog__action-button ${newIsCollaborator ? "is-danger" : "primary-button"}`

      const statusEl = button.closest("li")?.querySelector("small")
      if (statusEl) {
        statusEl.textContent = newIsCollaborator ? "Collaborator" : "Not shared"
      }

      this.showFeedback(newIsCollaborator ? "Playlist shared successfully." : "Collaborator removed.")
    } catch (error) {
      button.textContent = originalText
      this.showFeedback(error.message, true)
    } finally {
      button.disabled = false
    }
  }

  showFeedback(message, isError = false) {
    if (!this.hasFeedbackTarget) return
    this.feedbackTarget.textContent = message
    this.feedbackTarget.className = `redesign-share-playlist-dialog__feedback ${isError ? "is-error" : "is-success"}`
  }

  clearFeedback() {
    if (!this.hasFeedbackTarget) return
    this.feedbackTarget.textContent = ""
    this.feedbackTarget.className = "redesign-share-playlist-dialog__feedback"
  }

  escape(str) {
    const div = document.createElement("div")
    div.textContent = str
    return div.innerHTML
  }
}
