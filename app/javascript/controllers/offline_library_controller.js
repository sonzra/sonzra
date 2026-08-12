import { Controller } from "@hotwired/stimulus"
import { OfflineMediaStore } from "offline_media_store"

export default class extends Controller {
  static targets = [ "list", "empty", "count", "title", "back", "description", "storage", "intro", "detailBack", "detailHero", "trackSection", "trackList" ]

  connect() {
    this.boundRestoreView = this.restoreView.bind(this)
    window.addEventListener("popstate", this.boundRestoreView)
    this.restoreView()
    window.requestAnimationFrame(() => this.playerController()?.setOfflineQueue(this.store().catalog()))
    this.refreshStorageEstimate()
  }

  disconnect() {
    window.removeEventListener("popstate", this.boundRestoreView)
  }

  async remove(event) {
    await this.store().remove(event.currentTarget.dataset.offlineSource)
    this.selectedAlbumKey ? this.renderAlbum(this.selectedAlbumKey) : this.renderAlbums()
    this.refreshStorageEstimate()
  }

  async removeAlbum(event) {
    const album = this.albumFor(event.currentTarget.dataset.offlineAlbumKey)
    if (!album) return

    event.currentTarget.disabled = true
    await this.store().removeAll(album.tracks.map((track) => track.source))
    this.renderAlbums()
    this.refreshStorageEstimate()
  }

  toggleAlbumOptions(event) {
    event.stopPropagation()
    const menu = event.currentTarget.nextElementSibling
    const expanded = event.currentTarget.getAttribute("aria-expanded") === "true"
    event.currentTarget.setAttribute("aria-expanded", String(!expanded))
    menu.hidden = expanded
  }

  openAlbum(event) {
    const key = event.currentTarget.dataset.offlineAlbumKey
    if (!this.albumFor(key)) return

    history.pushState({ offlineAlbum: key }, "", `#album-${encodeURIComponent(key)}`)
    this.renderAlbum(key)
  }

  backToAlbums() {
    if (history.state?.offlineAlbum) {
      history.back()
    } else {
      this.renderAlbums()
    }
  }

  restoreView() {
    const key = history.state?.offlineAlbum
    key && this.albumFor(key) ? this.renderAlbum(key) : this.renderAlbums()
  }

  renderAlbums() {
    const albums = this.albums()
    this.selectedAlbumKey = null
    this.element.classList.remove("detail-page")
    this.introTarget.hidden = false
    this.detailBackTarget.hidden = true
    this.detailHeroTarget.hidden = true
    this.trackSectionTarget.hidden = true
    this.listTarget.hidden = false
    this.storageTarget.hidden = !this.storageTarget.textContent
    this.titleTarget.textContent = "Downloads"
    this.backTarget.hidden = true
    this.descriptionTarget.hidden = false
    this.emptyTarget.hidden = albums.length > 0
    this.countTarget.textContent = albums.length === 1 ? "1 downloaded album" : `${albums.length} downloaded albums`
    this.listTarget.classList.remove("offline-downloads__list--detail")
    this.listTarget.textContent = ""
    albums.forEach((album) => this.listTarget.append(this.albumCard(album)))
  }

  renderAlbum(key) {
    const album = this.albumFor(key)
    if (!album) return this.renderAlbums()

    this.selectedAlbumKey = key
    this.element.classList.add("detail-page")
    this.introTarget.hidden = true
    this.detailBackTarget.hidden = false
    this.descriptionTarget.hidden = true
    this.storageTarget.hidden = true
    this.emptyTarget.hidden = true
    this.listTarget.hidden = true
    this.detailHeroTarget.hidden = false
    this.trackSectionTarget.hidden = false
    this.renderAlbumHero(album)
    this.trackListTarget.textContent = ""
    album.tracks.forEach((track, index) => this.trackListTarget.append(this.trackElement(track, album, index)))
  }

  albums() {
    const albums = new Map()
    const collectionsBySource = new Map()
    this.store().collections().forEach((collection) => {
      collection.sources.forEach((source) => collectionsBySource.set(source, collection))
    })

    this.store().catalog().forEach((track) => {
      const collection = collectionsBySource.get(track.source)
      const key = track.albumId || collection?.queueUrl || track.album || `track:${track.source}`
      const album = albums.get(key) || {
        key,
        title: track.album || collection?.title || track.title || "Untitled album",
        artist: track.albumArtist || collection?.artist || track.artist || "Unknown artist",
        artwork: track.artwork || collection?.artwork,
        tracks: [],
        downloadedAt: track.downloadedAt
      }
      album.tracks.push(track)
      if (String(track.downloadedAt || "") > String(album.downloadedAt || "")) album.downloadedAt = track.downloadedAt
      albums.set(key, album)
    })

    return Array.from(albums.values()).sort((first, second) => String(second.downloadedAt || "").localeCompare(String(first.downloadedAt || "")))
  }

  albumCard(album) {
    const item = document.createElement("li")
    item.className = "offline-downloads__album-card listen-card"

    const open = document.createElement("button")
    open.type = "button"
    open.className = "offline-downloads__album-open listen-card__art"
    open.dataset.offlineAlbumKey = album.key
    open.ariaLabel = `Open ${album.title}`
    open.addEventListener("click", (event) => this.openAlbum(event))

    const artwork = document.createElement("img")
    artwork.className = "offline-downloads__album-art"
    artwork.src = album.artwork || "/brand/sonzra-mark.svg"
    artwork.alt = ""

    const details = document.createElement("div")
    details.className = "offline-downloads__details"
    const title = document.createElement("strong")
    title.textContent = album.title
    const artist = document.createElement("span")
    artist.textContent = album.artist
    const count = document.createElement("small")
    count.textContent = album.tracks.length === 1 ? "1 downloaded track" : `${album.tracks.length} downloaded tracks`
    details.append(title, artist, count)
    open.append(artwork)

    const play = document.createElement("button")
    play.type = "button"
    play.className = "offline-downloads__album-play listen-card__play"
    play.dataset.offlineAlbumKey = album.key
    play.ariaLabel = `Play ${album.title}`
    play.innerHTML = this.playIcon()
    play.addEventListener("click", (event) => this.playAlbum(event))

    const options = document.createElement("div")
    options.className = "listen-card__options offline-downloads__album-options"
    const toggle = document.createElement("button")
    toggle.type = "button"
    toggle.className = "listen-card__options-toggle"
    toggle.ariaLabel = `Options for ${album.title}`
    toggle.setAttribute("aria-expanded", "false")
    toggle.innerHTML = this.optionsIcon()
    toggle.addEventListener("click", (event) => this.toggleAlbumOptions(event))

    const menu = document.createElement("div")
    menu.className = "offline-downloads__album-menu"
    menu.hidden = true
    const remove = document.createElement("button")
    remove.type = "button"
    remove.className = "offline-downloads__album-remove"
    remove.dataset.offlineAlbumKey = album.key
    remove.ariaLabel = `Remove ${album.title} downloads`
    remove.textContent = "Remove"
    remove.addEventListener("click", (event) => this.removeAlbum(event))

    menu.append(remove)
    options.append(toggle, menu)
    item.append(open, play, options, details)
    return item
  }

  renderAlbumHero(album) {
    this.detailHeroTarget.textContent = ""
    const artwork = document.createElement("div")
    artwork.className = "detail-hero__art"
    const image = document.createElement("img")
    image.src = album.artwork || "/brand/sonzra-mark.svg"
    image.alt = ""
    artwork.append(image)

    const play = document.createElement("button")
    play.type = "button"
    play.className = "detail-hero__album-play"
    play.ariaLabel = `Play ${album.title}`
    play.innerHTML = this.playIcon()
    play.addEventListener("click", () => this.playerController()?.setOfflineQueue(album.tracks, { autoplay: true }))

    const options = document.createElement("div")
    options.className = "listen-card__options offline-downloads__detail-options"
    const toggle = document.createElement("button")
    toggle.type = "button"
    toggle.className = "listen-card__options-toggle"
    toggle.ariaLabel = `Options for ${album.title}`
    toggle.setAttribute("aria-expanded", "false")
    toggle.innerHTML = this.optionsIcon()
    toggle.addEventListener("click", (event) => this.toggleAlbumOptions(event))

    const menu = document.createElement("div")
    menu.className = "offline-downloads__album-menu"
    menu.hidden = true
    const remove = document.createElement("button")
    remove.type = "button"
    remove.className = "offline-downloads__detail-remove"
    remove.dataset.offlineAlbumKey = album.key
    remove.ariaLabel = `Remove ${album.title} from this device`
    remove.textContent = "Remove download"
    remove.addEventListener("click", (event) => this.removeAlbum(event))
    menu.append(remove)
    options.append(toggle, menu)
    artwork.append(play, options)

    const details = document.createElement("div")
    const kind = document.createElement("p")
    kind.className = "detail-hero__kind"
    kind.textContent = "Album"
    const title = document.createElement("div")
    title.className = "detail-hero__title"
    const heading = document.createElement("h1")
    heading.textContent = album.title
    title.append(heading)
    const artist = document.createElement("p")
    artist.className = "detail-hero__artist"
    artist.textContent = album.artist
    const release = document.createElement("p")
    release.className = "detail-hero__release"
    release.textContent = album.tracks.length === 1 ? "1 track" : `${album.tracks.length} tracks`
    details.append(kind, title, artist, release)
    this.detailHeroTarget.append(artwork, details)
  }

  trackElement(track, album, index) {
    const item = document.createElement("li")
    const number = document.createElement("span")
    number.textContent = String(index + 1)
    const title = document.createElement("strong")
    title.textContent = track.title || "Untitled track"
    const duration = document.createElement("time")
    duration.textContent = track.duration || ""

    const play = document.createElement("button")
    play.type = "button"
    play.className = "offline-downloads__track-action listen-card__play"
    play.dataset.offlineAlbumKey = album.key
    play.dataset.offlineSource = track.source
    play.ariaLabel = `Play ${track.title || "track"}`
    play.innerHTML = this.playIcon()
    play.addEventListener("click", (event) => this.playTrack(event))

    const queue = document.createElement("button")
    queue.type = "button"
    queue.className = "offline-downloads__track-action track-list__queue"
    queue.ariaLabel = `Add ${track.title || "track"} to queue`
    queue.innerHTML = this.queueIcon()
    queue.addEventListener("click", () => this.playerController()?.appendQueue({ params: track }))

    const remove = document.createElement("button")
    remove.type = "button"
    remove.className = "offline-downloads__track-action track-list__download offline-downloads__track-remove"
    remove.dataset.offlineSource = track.source
    remove.ariaLabel = `Remove ${track.title || "track"} download`
    remove.innerHTML = this.trashIcon()
    remove.addEventListener("click", (event) => this.remove(event))

    item.append(number, title, duration, play, queue, remove)
    return item
  }

  playAlbum(event) {
    const album = this.albumFor(event.currentTarget.dataset.offlineAlbumKey)
    if (album) this.playerController()?.setOfflineQueue(album.tracks, { autoplay: true })
  }

  playTrack(event) {
    const album = this.albumFor(event.currentTarget.dataset.offlineAlbumKey)
    if (!album) return

    this.playerController()?.setOfflineQueue(album.tracks, {
      source: event.currentTarget.dataset.offlineSource,
      autoplay: true
    })
  }

  albumFor(key) {
    return this.albums().find((album) => album.key === key)
  }

  store() {
    return this.cachedStore ||= new OfflineMediaStore({ scope: document.body.dataset.offlineMediaScopeValue })
  }

  playerController() {
    return this.application.getControllerForElementAndIdentifier(document.documentElement, "player") || this.application.getControllerForElementAndIdentifier(document.body, "player")
  }

  playIcon() {
    return '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="m5 3 14 9-14 9Z" fill="currentColor"/></svg>'
  }

  optionsIcon() {
    return '<svg viewBox="0 0 24 24" aria-hidden="true"><circle cx="5" cy="12" r="1.5" fill="currentColor"/><circle cx="12" cy="12" r="1.5" fill="currentColor"/><circle cx="19" cy="12" r="1.5" fill="currentColor"/></svg>'
  }

  queueIcon() {
    return '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M4 6h10M4 12h10M4 18h10M18 10v8M14 14h8" fill="none" stroke="currentColor" stroke-linecap="round" stroke-width="2"/></svg>'
  }

  trashIcon() {
    return '<svg viewBox="0 0 24 24" aria-hidden="true"><path d="M4 7h16M10 11v6M14 11v6M9 7l1-2h4l1 2M6 7l1 13h10l1-13" fill="none" stroke="currentColor" stroke-linecap="round" stroke-linejoin="round" stroke-width="2"/></svg>'
  }

  async refreshStorageEstimate() {
    if (!this.hasStorageTarget) return

    const estimate = await this.store().storageEstimate?.()
    if (!estimate?.quota) return

    const used = Number(estimate.usage) || 0
    this.storageTarget.textContent = `This browser uses ${this.formatBytes(used)} for Sonzra and other site data`
    this.storageTarget.hidden = false
  }

  formatBytes(value) {
    if (value < 1_024 * 1_024) return `${Math.ceil(value / 1_024)} KB`

    return `${(value / (1_024 * 1_024)).toFixed(1)} MB`
  }
}
