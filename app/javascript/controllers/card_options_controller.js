import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["sheet", "queueAction", "resetAction", "favoriteAction", "favoriteLabel", "playlistAction", "deletePlaylistAction", "playlistDialog", "playlistList", "playlistName", "playlistFeedback", "panel", "loader", "loaderMessage"]

  connect() {
    this.boundCloseOnOutsideClick = this.closeOnOutsideClick.bind(this)
  }

  disconnect() {
    this.cancelPress()
    window.clearTimeout(this.closeTimeout)
    window.clearTimeout(this.sheetClickTimeout)
    this.resetSheetDrag()
    window.cancelAnimationFrame(this.openFrame)
    this.stopListeningForOutsideClick()
  }

  startPress(event) {
    if (event.target.closest("button, input, label, select, textarea")) return

    this.cancelPress()
    this.pressedCard = event.currentTarget
    this.pressTimeout = window.setTimeout(() => {
      this.open(this.pressedCard)
      this.shouldConsumeClick = true
    }, 550)
  }

  cancelPress() {
    window.clearTimeout(this.pressTimeout)
    this.pressTimeout = null
  }

  consumeClick(event) {
    if (!this.shouldConsumeClick) return

    this.shouldConsumeClick = false
    event.preventDefault()
    event.stopImmediatePropagation()
  }

  preventContextMenu(event) {
    event.preventDefault()
  }

  toggle(event) {
    event.preventDefault()
    event.stopPropagation()
    const card = event.currentTarget.closest(".listen-card")
    if (!card) return

    this.sheetTarget.hidden ? this.open(card, event.currentTarget) : this.close()
  }

  open(card, toggle = null) {
    const playButton = card.querySelector(".listen-card__play")
    if (!playButton) return

    this.configureQueueAction(playButton)
    this.activeCard = card
    window.clearTimeout(this.closeTimeout)
    window.cancelAnimationFrame(this.openFrame)
    this.sheetTarget.hidden = false
    this.sheetTarget.classList.remove("is-closing")
    if (toggle) {
      const rect = toggle.getBoundingClientRect()
      this.sheetTarget.style.setProperty("--menu-left", `${Math.max(8, rect.right - 166)}px`)
      this.sheetTarget.style.setProperty("--menu-top", `${rect.bottom + 6}px`)
    }
    this.openFrame = window.requestAnimationFrame(() => this.sheetTarget.classList.add("is-open"))
    if (!this.isMobileSheet()) document.addEventListener("click", this.boundCloseOnOutsideClick)
  }

  close(event) {
    if (event?.type === "touchend") this.ignoreNextSheetClick()
    if (event?.type === "click" && this.shouldIgnoreSheetClick) return

    event?.preventDefault()
    event?.stopPropagation()

    if (!this.hasSheetTarget || this.sheetTarget.hidden) return

    this.cancelPress()
    this.shouldConsumeClick = false
    window.cancelAnimationFrame(this.openFrame)
    this.activeCard = null
    this.stopListeningForOutsideClick()
    if (!this.isMobileSheet()) {
      this.sheetTarget.hidden = true
      this.sheetTarget.classList.remove("is-open", "is-closing")
      return
    }

    this.sheetTarget.classList.remove("is-open")
    this.sheetTarget.classList.add("is-closing")
    window.clearTimeout(this.closeTimeout)
    this.closeTimeout = window.setTimeout(() => {
      this.sheetTarget.hidden = true
      this.sheetTarget.classList.remove("is-closing")
    }, 220)
  }

  configureQueueAction(playButton) {
    const attributes = ["source", "item-id", "reporting-url", "title", "artist", "artwork", "duration", "start-position", "resumable", "queue-url"]
    attributes.forEach((name) => this.queueActionTarget.removeAttribute(`data-player-${name}-param`))
    const values = {
      source: playButton.dataset.playerSourceParam,
      "item-id": playButton.dataset.playerItemIdParam,
      "reporting-url": playButton.dataset.playerReportingUrlParam,
      title: playButton.dataset.playerTitleParam,
      artist: playButton.dataset.playerArtistParam,
      artwork: playButton.dataset.playerArtworkParam,
      duration: playButton.dataset.playerDurationParam,
      "start-position": playButton.dataset.playerStartPositionParam,
      resumable: playButton.dataset.playerResumableParam,
      "queue-url": playButton.dataset.playerQueueUrlParam
    }
    Object.entries(values).forEach(([name, value]) => {
      if (value) this.queueActionTarget.setAttribute(`data-player-${name}-param`, value)
    })

    const resetUrl = playButton.dataset.cardOptionsResetUrlParam
    this.resetActionTarget.hidden = !resetUrl
    this.resetActionTarget.dataset.cardOptionsResetUrlParam = resetUrl || ""

    const options = playButton.closest(".listen-card")?.querySelector(".listen-card__options")
    const favoriteUrl = options?.dataset.cardOptionsFavoriteUrl
    this.favoriteActionTarget.hidden = !favoriteUrl
    this.favoriteActionTarget.dataset.cardOptionsFavoriteUrl = favoriteUrl || ""
    this.favoriteActionTarget.dataset.cardOptionsFavorite = options?.dataset.cardOptionsFavorite || "false"
    this.favoriteLabelTarget.textContent = this.favoriteActionTarget.dataset.cardOptionsFavorite === "true" ? "Remove from favourites" : "Add to favourites"
    this.playlistActionTarget.hidden = !options?.dataset.cardOptionsPlaylistsUrl
    this.playlistActionTarget.dataset.cardOptionsPlaylistsUrl = options?.dataset.cardOptionsPlaylistsUrl || ""
    this.playlistActionTarget.dataset.cardOptionsItemId = options?.dataset.cardOptionsItemId || ""
    this.playlistActionTarget.dataset.cardOptionsItemType = options?.dataset.cardOptionsItemType || ""
    this.deletePlaylistActionTarget.hidden = !options?.dataset.cardOptionsDeletePlaylistUrl
    this.deletePlaylistActionTarget.dataset.cardOptionsDeletePlaylistUrl = options?.dataset.cardOptionsDeletePlaylistUrl || ""
  }

  async openPlaylistPicker() {
    this.playlistListTarget.textContent = ""
    this.playlistFeedbackTarget.textContent = ""
    this.playlistNameTarget.value = ""
    this.close()
    this.playlistDialogTarget.showModal()
    this.renderPlaylistLoadingState()

    if (this.playlistsCache) {
      this.renderPlaylists(this.playlistsCache)
      return
    }

    const response = await fetch(this.playlistActionTarget.dataset.cardOptionsPlaylistsUrl, { headers: { Accept: "application/json" } })
    if (!response.ok) {
      this.playlistFeedbackTarget.textContent = "Couldn’t load playlists right now."
      this.playlistListTarget.textContent = ""
      return
    }

    this.playlistsCache = await response.json()
    this.renderPlaylists(this.playlistsCache)
  }

  openPlaylistPickerForItem({ playlistsUrl, itemId, itemType = "Audio" }) {
    if (!playlistsUrl || !itemId) return false

    this.playlistActionTarget.dataset.cardOptionsPlaylistsUrl = playlistsUrl
    this.playlistActionTarget.dataset.cardOptionsItemId = itemId
    this.playlistActionTarget.dataset.cardOptionsItemType = itemType
    this.playlistActionTarget.hidden = false
    this.openPlaylistPicker()
    return true
  }

  closePlaylistPicker() {
    if (this.playlistDialogTarget.open) this.playlistDialogTarget.close()
  }

  async createPlaylist(event) {
    event.preventDefault()
    this.showLoader("Creating playlist…")
    const response = await fetch(this.playlistActionTarget.dataset.cardOptionsPlaylistsUrl, { method: "POST", headers: { Accept: "application/json", "Content-Type": "application/json", "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content }, body: JSON.stringify({ name: this.playlistNameTarget.value }) })
    if (!response.ok) {
      this.hideLoader()
      this.playerController()?.showFeedback("Couldn’t create this playlist right now")
      return
    }

    await this.addToPlaylist(await response.json())
  }

  async addToPlaylist(playlistId) {
    const normalizedPlaylistId = this.normalizePlaylistId(playlistId)
    if (!normalizedPlaylistId) {
      this.hideLoader()
      this.playerController()?.showFeedback("Couldn’t create this playlist right now")
      return
    }

    const url = `${this.playlistActionTarget.dataset.cardOptionsPlaylistsUrl}/${normalizedPlaylistId}/items`
    this.closePlaylistPicker()
    const response = await fetch(url, { method: "POST", headers: { Accept: "application/json", "Content-Type": "application/json", "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content }, body: JSON.stringify({ item_id: this.playlistActionTarget.dataset.cardOptionsItemId, item_type: this.playlistActionTarget.dataset.cardOptionsItemType }) })
    if (!response.ok) {
      this.hideLoader()
      this.playerController()?.showFeedback(this.playlistActionTarget.dataset.cardOptionsItemType === "MusicAlbum" ? "Couldn’t add this album to the playlist" : "Couldn’t add this track to the playlist")
      return
    }
    this.hideLoader()
    this.playerController()?.showFeedback(this.playlistActionTarget.dataset.cardOptionsItemType === "MusicAlbum" ? "Album added to playlist" : "Track added to playlist")
  }

  playerController() {
    return [document.documentElement, document.body, this.element]
      .map((element) => this.application.getControllerForElementAndIdentifier(element, "player"))
      .find(Boolean)
  }

  normalizePlaylistId(playlistId) {
    if (typeof playlistId === "string") return playlistId
    if (typeof playlistId === "number") return String(playlistId)
    if (playlistId && typeof playlistId === "object") return playlistId.id || playlistId.Id || null

    return null
  }

  async toggleFavorite(event) {
    if (event.type === "touchend") this.ignoreNextSheetClick()
    if (event.type === "click" && this.shouldIgnoreSheetClick) return

    event.preventDefault()
    event.stopPropagation()
    const card = this.activeCard
    this.close(event)
    this.showLoader("Updating favourite…")
    const button = this.favoriteActionTarget
    const favorite = button.dataset.cardOptionsFavorite !== "true"
    const response = await fetch(button.dataset.cardOptionsFavoriteUrl, {
      method: "PATCH",
      headers: {
        Accept: "application/json",
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content
      },
      body: JSON.stringify({ favorite })
    })
    if (!response.ok) {
      this.hideLoader()
      this.playerController()?.showFeedback("Couldn’t update favourites right now")
      return
    }

    this.hideLoader()
    button.dataset.cardOptionsFavorite = String(favorite)
    this.favoriteLabelTarget.textContent = favorite ? "Remove from favourites" : "Add to favourites"
    const options = card?.querySelector(".listen-card__options")
    if (options) options.dataset.cardOptionsFavorite = String(favorite)
  }

  async deletePlaylist(event) {
    if (event.type === "touchend") this.ignoreNextSheetClick()
    if (event.type === "click" && this.shouldIgnoreSheetClick) return

    event.preventDefault()
    event.stopPropagation()
    const card = this.activeCard
    this.close(event)
    this.showLoader("Deleting playlist…")

    const response = await fetch(this.deletePlaylistActionTarget.dataset.cardOptionsDeletePlaylistUrl, {
      method: "DELETE",
      headers: {
        Accept: "application/json",
        "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content
      }
    })
    if (!response.ok) {
      this.hideLoader()
      this.playerController()?.showFeedback((await this.errorMessage(response)) || "Jellyfin couldn’t delete this playlist")
      return
    }

    this.hideLoader()
    this.playerController()?.showFeedback("Playlist deleted")
    card?.remove()
  }

  async removePlaylistTrack(event) {
    event.preventDefault()
    event.stopPropagation()
    const row = event.currentTarget.closest("li")
    this.showLoader("Removing song…")

    const response = await fetch(event.currentTarget.dataset.cardOptionsRemovePlaylistTrackUrlParam, {
      method: "DELETE",
      headers: {
        Accept: "application/json",
        "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content
      }
    })
    if (!response.ok) {
      this.hideLoader()
      this.playerController()?.showFeedback("Couldn’t remove this song from the playlist")
      return
    }

    this.hideLoader()
    row?.remove()
    this.playerController()?.showFeedback("Song removed from playlist")
  }

  async resetPlaybackPosition(event) {
    if (event.type === "touchend") this.ignoreNextSheetClick()
    if (event.type === "click" && this.shouldIgnoreSheetClick) return

    event.preventDefault()
    event.stopPropagation()
    const card = this.activeCard
    this.close(event)
    this.showLoader("Resetting progress…")

    const response = await fetch(event.currentTarget.dataset.cardOptionsResetUrlParam, {
      method: "POST",
      headers: {
        Accept: "application/json",
        "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content
      }
    })
    if (!response.ok) {
      this.hideLoader()
      this.playerController()?.showFeedback("Couldn’t reset progress right now")
      return
    }

    this.hideLoader()
    card?.remove()
  }

  appendToQueue(event) {
    if (event.type === "touchend") this.ignoreNextSheetClick()
    if (event.type === "click" && this.shouldIgnoreSheetClick) return

    event.preventDefault()
    event.stopPropagation()
    this.close(event)
    this.application.getControllerForElementAndIdentifier(document.documentElement, "player")?.appendQueue({
      params: this.playerParams()
    })
  }

  showLoader(message) {
    if (!this.hasLoaderTarget) return

    this.loaderMessageTarget.textContent = message
    this.loaderTarget.hidden = false
  }

  hideLoader() {
    if (!this.hasLoaderTarget) return

    this.loaderTarget.hidden = true
  }

  async errorMessage(response) {
    try {
      const result = await response.json()
      return result.error
    } catch (_) {
      return null
    }
  }

  renderPlaylistLoadingState() {
    const item = document.createElement("li")
    item.className = "playlist-picker__loading"
    item.textContent = "Loading playlists…"
    this.playlistListTarget.replaceChildren(item)
  }

  renderPlaylists(playlists) {
    this.playlistListTarget.textContent = ""
    playlists.forEach((playlist) => {
      const button = document.createElement("button")
      button.type = "button"
      button.className = "playlist-picker__choice"
      button.innerHTML = `<span>${playlist.Name}</span><span>›</span>`
      button.addEventListener("click", () => this.addToPlaylist(playlist.Id))
      const item = document.createElement("li")
      item.append(button)
      this.playlistListTarget.append(item)
    })
  }

  startSheetDrag(event) {
    if (!this.isMobileSheet() || event.target.closest("button")) return

    const touch = event.touches[0]
    const panelTop = this.panelTarget.getBoundingClientRect().top
    if (touch.clientY - panelTop > 56) return

    this.sheetDragStartY = touch.clientY
    this.sheetDragOffset = 0
    this.sheetTarget.classList.add("is-dragging")
  }

  dragSheet(event) {
    if (this.sheetDragStartY === undefined) return

    this.sheetDragOffset = Math.max(0, event.touches[0].clientY - this.sheetDragStartY)
    this.panelTarget.style.setProperty("--sheet-drag-offset", `${this.sheetDragOffset}px`)
    event.preventDefault()
  }

  finishSheetDrag() {
    if (this.sheetDragStartY === undefined) return

    const shouldDismiss = this.sheetDragOffset > 96
    this.resetSheetDrag()
    if (shouldDismiss) this.close()
  }

  closeOnOutsideClick(event) {
    if (!this.sheetTarget.contains(event.target)) this.close()
  }

  stopListeningForOutsideClick() {
    document.removeEventListener("click", this.boundCloseOnOutsideClick)
  }

  ignoreNextSheetClick() {
    this.shouldIgnoreSheetClick = true
    window.clearTimeout(this.sheetClickTimeout)
    this.sheetClickTimeout = window.setTimeout(() => {
      this.shouldIgnoreSheetClick = false
    }, 500)
  }

  playerParams() {
    const button = this.queueActionTarget.dataset

    return {
      source: button.playerSourceParam,
      itemId: button.playerItemIdParam,
      reportingUrl: button.playerReportingUrlParam,
      title: button.playerTitleParam,
      artist: button.playerArtistParam,
      artwork: button.playerArtworkParam,
      duration: button.playerDurationParam,
      startPosition: button.playerStartPositionParam,
      resumable: button.playerResumableParam,
      queueUrl: button.playerQueueUrlParam
    }
  }

  resetSheetDrag() {
    this.sheetDragStartY = undefined
    this.sheetDragOffset = 0
    if (!this.hasSheetTarget) return

    this.sheetTarget.classList.remove("is-dragging")
    if (this.hasPanelTarget) this.panelTarget.style.removeProperty("--sheet-drag-offset")
  }

  isMobileSheet() {
    return window.matchMedia("(max-width: 760px)").matches
  }
}
