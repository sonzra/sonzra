import { Controller } from "@hotwired/stimulus"
import { OfflineMediaStore } from "offline_media_store"

export default class extends Controller {
  static values = { scope: String }

  connect() {
    const store = this.store()
    if (store.catalog().length > 0) store.warmOfflineShell()
    store.requestPersistentStorage()
  }

  async signOut(event) {
    event.preventDefault()

    await this.store().clear()
    event.currentTarget.closest("form")?.submit()
  }

  async download(event) {
    const button = event.currentTarget
    if (button.dataset.offlineDownloading === "true") return this.cancelCollectionDownload(button)

    const track = this.trackFrom(button)
    if (!track.source) return this.downloadCollection(button)

    button.disabled = true
    try {
      await this.store().download(track)
      this.store().warmOfflineShell()
      this.feedback("Available offline")
    } catch (error) {
      this.feedback(error.message || "Sonzra couldn’t save this download.")
      button.disabled = false
    }
  }

  async downloadCollection(button) {
    const queueUrl = button.dataset.offlineMediaQueueUrl
    if (!queueUrl) return

    const originalLabel = button.getAttribute("aria-label")
    const originalContent = button.innerHTML
    this.downloadAbortController = new AbortController()
    button.dataset.offlineDownloading = "true"
    button.classList.add("is-downloading")
    button.setAttribute("aria-label", "Cancel offline download")
    button.textContent = "Cancel"

    try {
      const response = await fetch(queueUrl, { headers: { Accept: "application/json" } })
      if (!response.ok) throw new Error("Sonzra couldn’t load this album for download.")

      const tracks = (await response.json()).items.map((item) => ({
        source: item.source,
        title: item.title,
        artist: item.artist,
        artwork: item.artwork,
        duration: item.duration,
        itemId: item.item_id,
        albumId: item.album_id,
        album: item.album,
        albumArtist: item.album_artist,
        reportingUrl: item.reporting_url
      }))
      await this.store().downloadAll(tracks, (completed, total) => {
        button.textContent = `${completed} / ${total}`
        this.feedback(`Downloading ${completed} of ${total}…`)
      }, { signal: this.downloadAbortController.signal })
      this.store().saveCollection(queueUrl, tracks, {
        title: button.dataset.offlineMediaTitle,
        artist: button.dataset.offlineMediaArtist,
        artwork: button.dataset.offlineMediaArtwork
      })
      this.store().warmOfflineShell()
      this.feedback("Available offline")
    } catch (error) {
      this.feedback(error?.name === "AbortError" ? "Offline download cancelled" : error.message || "Sonzra couldn’t save this album.")
    } finally {
      this.downloadAbortController = null
      delete button.dataset.offlineDownloading
      button.classList.remove("is-downloading")
      button.setAttribute("aria-label", originalLabel || "Download for offline playback")
      button.innerHTML = originalContent
    }
  }

  cancelCollectionDownload(button) {
    this.downloadAbortController?.abort()
    button.disabled = true
  }

  store() {
    return this.cachedStore ||= new OfflineMediaStore({ scope: this.scopeValue })
  }

  trackFrom(button) {
    return {
      source: button.dataset.offlineMediaSource,
      title: button.dataset.offlineMediaTitle,
      artist: button.dataset.offlineMediaArtist,
      artwork: button.dataset.offlineMediaArtwork,
      duration: button.dataset.offlineMediaDuration,
      itemId: button.dataset.offlineMediaItemId,
      albumId: button.dataset.offlineMediaAlbumId,
      album: button.dataset.offlineMediaAlbum,
      albumArtist: button.dataset.offlineMediaAlbumArtist,
      reportingUrl: button.dataset.offlineMediaReportingUrl
    }
  }

  feedback(message) {
    this.application.getControllerForElementAndIdentifier(document.documentElement, "player")?.showFeedback(message)
  }
}
