import { Controller } from "@hotwired/stimulus"
import { OfflineMediaStore } from "offline_media_store"

const PLAYER_STATE_KEY = "sonzra:player-state"
const LEGACY_QUEUE_KEY = "sonzra:queue"
const LEGACY_QUEUE_INDEX_KEY = "sonzra:queue-index"
const RADIO_TOP_UP_THRESHOLD = 2
const RADIO_TARGET_AHEAD = 8
const RADIO_MAX_QUEUE_SIZE = 24
const PLAYBACK_RECOVERY_DELAY = 8_000
const MAX_PLAYBACK_RECOVERY_ATTEMPTS = 2

export default class extends Controller {
  static targets = ["shell", "audio", "artwork", "title", "artist", "toggle", "timeline", "elapsed", "duration", "miniProgress", "queuePanel", "queueList", "queueFeedback", "expandedArtwork", "expandedTitle", "expandedArtist", "expandedToggle", "expandedTimeline", "expandedElapsed", "expandedDuration", "repeat", "favorite", "radio", "clearDialog", "queueView", "lyricsView", "queueTab", "lyricsTab", "lyricsStatus", "lyricsList", "lyricsFollow"]
  static values = { radioEnabled: Boolean, preferencesUrl: String, offline: Boolean }

  connect() {
    // The player is Turbo-permanent. During a deploy or a Turbo restoration it
    // can briefly retain markup from an older version of the component.
    // Do not let that incomplete markup prevent the page from connecting.
    if (!this.hasAudioTarget) return

    this.radioEnabled = this.radioEnabledValue === true
    this.offlineMode = this.offlineValue === true
    this.lyricsCache = new Map()
    this.lyricsFollowing = true
    this.relocateLegacyQueue()
    this.restoreVolume()
    this.restoreQueue()
    this.audioTarget.preload = "auto"
    this.audioTarget.playsInline = true
    this.configureAudioSession()
    this.bindEventHandlers()
    this.audioTarget.addEventListener("timeupdate", this.boundUpdateTimeline)
    this.audioTarget.addEventListener("loadedmetadata", this.boundUpdateTimeline)
    this.audioTarget.addEventListener("durationchange", this.boundUpdateTimeline)
    this.audioTarget.addEventListener("canplay", this.boundUpdateTimeline)
    this.audioTarget.addEventListener("canplay", this.boundHandleCanPlay)
    this.audioTarget.addEventListener("play", this.boundHandlePlay)
    this.audioTarget.addEventListener("pause", this.boundHandlePause)
    this.audioTarget.addEventListener("seeked", this.boundReportProgress)
    this.audioTarget.addEventListener("ended", this.boundPlayNext)
    this.audioTarget.addEventListener("waiting", this.boundHandleBuffering)
    this.audioTarget.addEventListener("stalled", this.boundHandleBuffering)
    this.audioTarget.addEventListener("error", this.boundHandlePlaybackError)
    window.addEventListener("pagehide", this.boundHandlePageHide)
    window.addEventListener("pageshow", this.boundReconcilePlayback)
    window.addEventListener("sonzra:native-media-command", this.boundHandleNativeMediaCommand)
    document.addEventListener("visibilitychange", this.boundHandleVisibilityChange)
    document.addEventListener("turbo:load", this.boundSyncPageTrackControls)
    this.reconcilePlayback()
    this.syncPageTrackControls()
  }

  offlineValueChanged(value) {
    this.offlineMode = value
  }

  disconnect() {
    if (!this.hasAudioTarget) return

    this.persistQueue({ force: true })
    this.audioTarget.removeEventListener("timeupdate", this.boundUpdateTimeline)
    this.audioTarget.removeEventListener("loadedmetadata", this.boundUpdateTimeline)
    this.audioTarget.removeEventListener("durationchange", this.boundUpdateTimeline)
    this.audioTarget.removeEventListener("canplay", this.boundUpdateTimeline)
    this.audioTarget.removeEventListener("canplay", this.boundHandleCanPlay)
    this.audioTarget.removeEventListener("play", this.boundHandlePlay)
    this.audioTarget.removeEventListener("pause", this.boundHandlePause)
    this.audioTarget.removeEventListener("seeked", this.boundReportProgress)
    this.audioTarget.removeEventListener("ended", this.boundPlayNext)
    this.audioTarget.removeEventListener("waiting", this.boundHandleBuffering)
    this.audioTarget.removeEventListener("stalled", this.boundHandleBuffering)
    this.audioTarget.removeEventListener("error", this.boundHandlePlaybackError)
    window.removeEventListener("pagehide", this.boundHandlePageHide)
    window.removeEventListener("pageshow", this.boundReconcilePlayback)
    window.removeEventListener("sonzra:native-media-command", this.boundHandleNativeMediaCommand)
    document.removeEventListener("visibilitychange", this.boundHandleVisibilityChange)
    document.removeEventListener("turbo:load", this.boundSyncPageTrackControls)
    this.stopProgressWatch()
    this.clearPlaybackRecovery()
    this.lyricsRequest?.abort()
    window.clearTimeout(this.lyricScrollTimeout)
  }

  async replaceQueue(event) {
    const tracks = (await this.tracksFor(event)).map((track) => this.normalizeTrack(track))
    if (tracks.length === 0) {
      this.showFeedback("Sonzra couldn’t load playable tracks.")
      return
    }

    if (event.params.radioEnabled === "true") {
      this.setRadioEnabled(true)
    } else if (event.params.queueUrl && this.radioEnabled) {
      this.setRadioEnabled(false)
    }
    this.queue = tracks
    this.currentIndex = 0
    this.recordRecommendationStart(event.params.recommendationCollectionId)
    this.persistQueue({ force: true })
    this.renderQueue()
    this.playCurrent()
  }

  recordRecommendationStart(collectionId) {
    if (!collectionId) return

    fetch(`/recommendation_collections/${collectionId}/events`, {
      method: "POST",
      headers: { "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content }
    }).catch(() => {})
  }

  async appendQueue(event) {
    const tracks = (await this.tracksFor(event)).map((track) => this.normalizeTrack(track))
    if (tracks.length === 0) {
      this.showFeedback("Sonzra couldn’t load playable tracks.")
      return
    }

    this.queue.push(...tracks)
    this.persistQueue({ force: true })
    this.renderQueue()
    this.showQueueFeedback(tracks)
    if (!this.audioTarget.src) this.playCurrent()
  }

  toggle() {
    if (!this.audioTarget.src) return

    if (this.audioTarget.paused) {
      this.playbackRequested = true
      const playback = this.audioTarget.play()
      this.monitorPlayback(playback)
    } else {
      this.playbackRequested = false
      this.clearPlaybackRecovery()
      this.audioTarget.pause()
    }
  }

  seek(event) {
    this.audioTarget.currentTime = event.currentTarget.value
    this.updateProgress(Number(event.currentTarget.value), Number(event.currentTarget.max))
    this.syncNativeMedia()
  }

  toggleQueue() {
    this.relocateLegacyQueue()
    if (!this.hasQueuePanelTarget) return

    if (this.queuePanelTarget.hidden) {
      this.openQueue()
    } else {
      this.closeQueue()
    }
  }

  previous() {
    if (this.currentIndex === 0) return

    this.currentIndex -= 1
    this.persistQueue({ force: true })
    this.renderQueue()
    this.playCurrent()
  }

  next() {
    if (this.currentIndex >= this.queue.length - 1) return

    this.currentIndex += 1
    this.persistQueue({ force: true })
    this.renderQueue()
    this.playCurrent()
  }

  toggleRepeat() {
    this.repeatMode = { off: "all", all: "one", one: "off" }[this.repeatMode || "off"]
    this.updateRepeatControls()
    this.persistQueue({ force: true })
  }

  async toggleRadio() {
    if (this.offlineMode) return

    this.setRadioEnabled(!this.radioEnabled, { feedback: this.radioEnabled ? "Radio off" : "Radio on" })
    if (this.radioEnabled) await this.maybeExtendRadioQueue()
  }

  async toggleFavorite() {
    if (this.offlineMode || !this.currentTrack?.source) return

    const favorite = !this.currentTrack.favorite
    const favoriteUrl = this.currentTrack.source.replace(/\/audio\/([^/?]+).*$/, "/favorites/$1")
    const response = await fetch(favoriteUrl, {
      method: "PATCH",
      headers: { Accept: "application/json", "Content-Type": "application/json", "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content },
      body: JSON.stringify({ favorite })
    })
    if (!response.ok) return

    this.currentTrack.favorite = favorite
    this.queue[this.currentIndex].favorite = favorite
    this.updateFavoriteControls()
    this.renderQueue()
    this.persistQueue({ force: true })
  }

  updateTimeline() {
    const duration = this.audioTarget.duration
    if (this.hasElapsedTarget) this.elapsedTarget.textContent = this.formatTime(this.audioTarget.currentTime)
    if (!Number.isFinite(duration)) return

    if (this.pendingStartPosition > 0) {
      this.audioTarget.currentTime = Math.min(this.pendingStartPosition, duration)
      this.pendingStartPosition = 0
    }

    this.timelineTargets.concat(this.expandedTimelineTargets).forEach((timeline) => {
      timeline.max = duration
      timeline.value = this.audioTarget.currentTime
    })
    this.updateProgress(this.audioTarget.currentTime, duration)
    this.syncBrowserMediaPosition()
    if (this.playbackRecoveryAttempts > 0 && this.audioTarget.currentTime >= (this.playbackRecoveryPosition || 0) + 15) {
      this.playbackRecoveryAttempts = 0
    }
    if (this.hasDurationTarget) this.durationTarget.textContent = this.formatTime(duration)
    if (this.hasExpandedElapsedTarget) this.expandedElapsedTarget.textContent = this.formatTime(this.audioTarget.currentTime)
    if (this.hasExpandedDurationTarget) this.expandedDurationTarget.textContent = this.formatTime(duration)
    this.updateActiveLyric()
    if (this.audioTarget.currentTime - (this.lastReportedPosition || 0) >= 15) this.reportProgress()
    this.persistQueue()
  }

  updateToggle() {
    const icon = this.audioTarget.paused ? this.icon("play") : this.icon("pause")
    const label = this.audioTarget.paused ? "Play" : "Pause"
    this.toggleTargets.concat(this.expandedToggleTargets).forEach((button) => {
      button.innerHTML = icon
      button.setAttribute("aria-label", label)
    })
    this.renderQueue()
    this.syncPageTrackControls()
  }

  handlePlay() {
    this.updateToggle()
    this.syncNativeMedia()
    this.syncBrowserMedia()
    this.startProgressWatch()
    this.reportPlayback(this.hasReportedStart ? "progress" : "started")
    this.hasReportedStart = true
    this.persistQueue({ force: true })
  }

  handlePause() {
    this.updateToggle()
    this.syncNativeMedia()
    this.syncBrowserMedia()
    this.stopProgressWatch()
    if (this.hasReportedStart) this.reportPlayback("progress")
    this.persistQueue({ force: true })
  }

  reportProgress() {
    this.reportPlayback("progress")
  }

  playNext() {
    if (this.advancingQueue) return

    this.advancingQueue = true
    if (this.repeatMode === "one") {
      this.audioTarget.currentTime = 0
      this.monitorPlayback(this.audioTarget.play())
    } else if (this.currentIndex >= this.queue.length - 1 && this.repeatMode === "all") {
      this.playQueueIndex(0)
    } else if (this.currentIndex >= this.queue.length - 1) {
      this.stopPlayback()
    } else {
      this.playQueueIndex(this.currentIndex + 1)
    }
    this.advancingQueue = false
  }

  handleBuffering() {
    if (!this.playbackRequested || this.audioTarget.ended) return

    this.schedulePlaybackRecovery(PLAYBACK_RECOVERY_DELAY)
  }

  handleCanPlay() {
    this.clearPlaybackRecovery()
  }

  handlePlaybackError() {
    if (this.schedulePlaybackRecovery(0)) return

    if (this.hasArtistTarget) this.artistTarget.textContent = "This track could not be played. Check the server logs and try again."
  }

  schedulePlaybackRecovery(delay) {
    if (!this.playbackRequested || !this.currentTrack?.source || this.audioTarget.ended) return false
    if (this.playbackRecoveryTimeout || this.recoveringPlayback) return true
    if ((this.playbackRecoveryAttempts || 0) >= MAX_PLAYBACK_RECOVERY_ATTEMPTS) return false

    const source = this.currentTrack.source
    this.playbackRecoveryTimeout = window.setTimeout(() => {
      this.playbackRecoveryTimeout = null
      this.recoverPlayback(source)
    }, delay)
    return true
  }

  recoverPlayback(source) {
    if (!this.playbackRequested || this.currentTrack?.source !== source || this.audioTarget.ended) return
    if ((this.playbackRecoveryAttempts || 0) >= MAX_PLAYBACK_RECOVERY_ATTEMPTS) return

    this.recoveringPlayback = true
    this.playbackRecoveryAttempts = (this.playbackRecoveryAttempts || 0) + 1
    this.pendingStartPosition = Number(this.audioTarget.currentTime) || this.pendingStartPosition || 0
    this.playbackRecoveryPosition = this.pendingStartPosition
    this.audioTarget.src = source
    this.audioTarget.load()
    this.monitorPlayback(this.audioTarget.play())
    this.recoveringPlayback = false
  }

  clearPlaybackRecovery() {
    window.clearTimeout(this.playbackRecoveryTimeout)
    this.playbackRecoveryTimeout = null
    this.recoveringPlayback = false
  }

  async tracksFor(event) {
    const params = {
      ...event.params,
      resumable: event.params.resumable || Boolean(event.currentTarget?.closest(".detail-hero--longform"))
    }
    if (!params.queueUrl) return [ this.trackFrom(params) ]

    try {
      const response = await fetch(params.queueUrl, { headers: { Accept: "application/json" } })
      if (!response.ok) return []

      return (await response.json()).items.map((track) => ({
        ...track,
        itemId: track.item_id,
        reportingUrl: track.reporting_url,
        radioUrl: track.radio_url,
        radioEligible: track.radio_eligible
      }))
    } catch (_) {
      return []
    }
  }

  trackFrom({ source, title, artist, artwork, duration, itemId, reportingUrl, startPosition, resumable, radioUrl, radioEligible, favorite }) {
    return {
      source,
      title,
      artist,
      artwork,
      duration,
      itemId,
      reportingUrl,
      startPosition,
      favorite: favorite === true || favorite === "true",
      resumable: resumable === true || resumable === "true",
      radioUrl,
      radioEligible: radioEligible === true || radioEligible === "true"
    }
  }

  playCurrent() {
    const track = this.queue[this.currentIndex]
    if (!track) return

    if (this.currentTrack && this.currentTrack !== track) this.reportPlayback("stopped")
    this.clearPlaybackRecovery()
    this.playbackRequested = true
    this.loadTrack(track)
    const playback = this.audioTarget.play()
    this.monitorPlayback(playback)
    this.maybeExtendRadioQueue()
  }

  setOfflineQueue(tracks, { source = null, autoplay = false } = {}) {
    const downloadedTracks = tracks.map((track) => this.normalizeTrack(track)).filter((track) => track.source)
    if (downloadedTracks.length === 0) return

    const persistedState = this.readPersistedState()
    const rememberedSource = persistedState.queue?.[persistedState.currentIndex]?.source
    const selectedSource = source || rememberedSource
    const selectedIndex = downloadedTracks.findIndex((track) => track.source === selectedSource)
    this.queue = downloadedTracks
    this.currentIndex = selectedIndex >= 0 ? selectedIndex : 0
    this.radioEnabled = false
    this.repeatMode = [ "off", "all", "one" ].includes(persistedState.repeatMode) ? persistedState.repeatMode : "off"
    this.loadTrack(this.queue[this.currentIndex], {
      startPosition: selectedSource === rememberedSource ? Number(persistedState.position) || 0 : 0
    })
    this.audioTarget.pause()
    this.persistQueue({ force: true })
    this.renderQueue()
    this.updateRepeatControls()
    this.updateRadioControls()
    if (autoplay) this.playCurrent()
  }

  restoreCurrentTrack() {
    const track = this.queue[this.currentIndex]
    if (!track) return

    if (this.audioTarget.src) {
      this.currentTrack = track
      this.syncBrowserMedia()
      this.syncPageTrackControls()
      return
    }

    this.loadTrack(track, { startPosition: this.savedPosition })
    this.audioTarget.pause()
  }

  loadTrack(track, { startPosition = track.startPosition } = {}) {
    this.lyricsRequest?.abort()
    this.currentLyrics = null
    this.activeLyricIndex = null
    this.lyricsFollowing = true
    this.currentTrack = track
    this.hasReportedStart = false
    this.lastReportedPosition = 0
    this.playbackRecoveryAttempts = 0
    this.playbackRecoveryPosition = 0
    this.audioTarget.src = track.source
    this.pendingStartPosition = Number(startPosition) || 0
    const artwork = track.artwork || "/brand/sonzra-mark.svg"
    this.titleTarget.textContent = track.title
    this.artistTarget.textContent = track.artist
    this.artworkTarget.src = artwork
    this.showPlayer()
    if (this.hasExpandedTitleTarget) this.expandedTitleTarget.textContent = track.title
    if (this.hasExpandedArtistTarget) this.expandedArtistTarget.textContent = track.artist
    if (this.hasExpandedArtworkTarget) this.expandedArtworkTarget.src = artwork
    this.resetTimeline()
    this.updateFavoriteControls()
    this.updateRadioControls()
    this.resetLyricsView()
    this.syncNativeMedia()
    this.syncBrowserMedia()
    this.syncPageTrackControls()
  }

  restoreQueue() {
    const savedState = this.readPersistedState()
    try {
      this.queue = Array.isArray(savedState.queue) ? savedState.queue.map((track) => this.normalizeTrack(track)) : []
      this.currentIndex = Math.min(Math.max(Number(savedState.currentIndex) || 0, 0), Math.max(this.queue.length - 1, 0))
      this.savedPosition = Number(savedState.position) || 0
      this.queueWasOpen = savedState.queueOpen === true
      this.repeatMode = [ "off", "all", "one" ].includes(savedState.repeatMode) ? savedState.repeatMode : "off"
      this.radioEnabled = savedState.radioEnabled === true || this.radioEnabled
    } catch (_) {
      this.queue = []
      this.currentIndex = 0
      this.savedPosition = 0
      this.queueWasOpen = false
      this.repeatMode = "off"
    }
    this.renderQueue()
    this.updateRepeatControls()
    this.updateRadioControls()
    this.restoreCurrentTrack()
    if (this.queueWasOpen && this.queue.length > 0 && this.hasQueuePanelTarget) {
      this.queuePanelTarget.hidden = false
      this.queuePanelTarget.classList.add("is-open")
    }
  }

  readPersistedState() {
    try {
      const state = JSON.parse(window.localStorage.getItem(PLAYER_STATE_KEY) || "null")
      if (state?.version === 1) return state

      return {
        queue: JSON.parse(sessionStorage.getItem(LEGACY_QUEUE_KEY) || "[]"),
        currentIndex: Number(sessionStorage.getItem(LEGACY_QUEUE_INDEX_KEY)) || 0,
        position: 0,
        queueOpen: false,
        repeatMode: "off",
        radioEnabled: this.radioEnabled
      }
    } catch (_) {
      return { queue: [], currentIndex: 0, position: 0, queueOpen: false, repeatMode: "off", radioEnabled: this.radioEnabled }
    }
  }

  persistQueue({ force = false } = {}) {
    if (!Array.isArray(this.queue)) return

    const position = Number(this.audioTarget?.currentTime) || this.pendingStartPosition || 0
    const second = Math.floor(position)
    if (!force && this.lastPersistedSecond === second) return

    this.lastPersistedSecond = second
    try {
      window.localStorage.setItem(PLAYER_STATE_KEY, JSON.stringify({
        version: 1,
        queue: this.queue,
        currentIndex: this.currentIndex,
        position,
        queueOpen: this.hasQueuePanelTarget && !this.queuePanelTarget.hidden && !this.queuePanelTarget.classList.contains("is-closing"),
        repeatMode: this.repeatMode || "off",
        radioEnabled: this.radioEnabled === true
      }))
    } catch (_) {
      // Storage can be unavailable in private browsing. Playback still works.
    }
  }

  renderQueue() {
    const firstVisibleIndex = Math.max(0, this.currentIndex - 3)
    if (!this.hasQueueListTarget) return

    this.queueListTarget.textContent = ""
    this.queue.slice(firstVisibleIndex).forEach((track, index) => {
      const item = document.createElement("li")
      const queueIndex = firstVisibleIndex + index
      item.classList.toggle("is-current", queueIndex === this.currentIndex)
      const artwork = document.createElement("img")
      artwork.src = track.artwork || "/brand/sonzra-mark.svg"
      artwork.alt = ""
      const details = document.createElement("div")
      details.className = "listen-queue__item-details"
      const title = document.createElement("strong")
      title.textContent = track.title
      const artist = document.createElement("span")
      artist.textContent = track.artist
      details.append(title, artist)
      const duration = document.createElement("time")
      duration.textContent = track.duration || "—"
      const playButton = document.createElement("button")
      playButton.type = "button"
      const isCurrent = queueIndex === this.currentIndex
      const isPaused = this.audioTarget.paused
      playButton.ariaLabel = `${isCurrent && !isPaused ? "Pause" : "Play"} ${track.title}`
      playButton.innerHTML = this.icon(isCurrent && !isPaused ? "pause" : "play", "listen-queue__item-play-icon")
      playButton.className = "listen-queue__item-action listen-queue__item-play"
      playButton.classList.toggle("is-current", isCurrent)
      playButton.addEventListener("click", () => isCurrent ? this.toggle() : this.playQueueIndex(queueIndex))
      const moreMenu = document.createElement("details")
      moreMenu.className = "listen-queue__item-menu"
      const moreToggle = document.createElement("summary")
      moreToggle.ariaLabel = `More actions for ${track.title}`
      moreToggle.innerHTML = this.icon("ellipsis")
      const moreActions = document.createElement("div")
      moreActions.className = "listen-queue__item-menu-actions"
      const closeMoreMenu = () => moreMenu.removeAttribute("open")
      if (!this.offlineMode) {
        const favoriteButton = document.createElement("button")
        favoriteButton.type = "button"
        favoriteButton.className = "listen-queue__item-menu-action listen-queue__item-favorite"
        favoriteButton.classList.toggle("is-active", track.favorite === true)
        favoriteButton.ariaLabel = track.favorite ? `Remove ${track.title} from favourites` : `Add ${track.title} to favourites`
        favoriteButton.innerHTML = `${this.icon(track.favorite ? "heart-filled" : "heart")}<span>${track.favorite ? "Remove from favourites" : "Add to favourites"}</span>`
        favoriteButton.addEventListener("click", () => { closeMoreMenu(); this.toggleQueuedFavorite(queueIndex) })
        const playlistButton = document.createElement("button")
        playlistButton.type = "button"
        playlistButton.className = "listen-queue__item-menu-action listen-queue__item-playlist"
        playlistButton.ariaLabel = `Add ${track.title} to playlist`
        playlistButton.innerHTML = `${this.icon("list-plus")}<span>Add to playlist</span>`
        playlistButton.addEventListener("click", () => { closeMoreMenu(); this.addQueuedTrackToPlaylist(queueIndex) })
        const downloadButton = document.createElement("button")
        downloadButton.type = "button"
        downloadButton.className = "listen-queue__item-menu-action listen-queue__item-download"
        downloadButton.ariaLabel = `Download ${track.title} for offline playback`
        downloadButton.innerHTML = `${this.icon("download")}<span>Download</span>`
        downloadButton.addEventListener("click", () => { closeMoreMenu(); this.downloadQueuedTrack(queueIndex, downloadButton) })
        moreActions.append(favoriteButton, playlistButton, downloadButton)
      }
      const removeButton = document.createElement("button")
      removeButton.type = "button"
      removeButton.className = "listen-queue__item-menu-action listen-queue__item-remove"
      removeButton.ariaLabel = `Remove ${track.title} from queue`
      removeButton.innerHTML = `${this.icon("x")}<span>Remove from queue</span>`
      removeButton.addEventListener("click", () => { closeMoreMenu(); this.removeQueuedTrack(queueIndex) })
      moreActions.append(removeButton)
      moreMenu.append(moreToggle, moreActions)
      item.append(artwork, details, duration, playButton, moreMenu)
      this.queueListTarget.appendChild(item)
    })
    if (this.queue.length === 0) this.queueListTarget.textContent = "Nothing queued"
  }

  updateRepeatControls() {
    const labels = { off: "Repeat off", all: "Repeat queue", one: "Repeat current track" }
    this.repeatTargets.forEach((button) => {
      button.classList.toggle("is-active", this.repeatMode !== "off")
      button.setAttribute("aria-label", labels[this.repeatMode])
      button.setAttribute("title", labels[this.repeatMode])
      button.innerHTML = this.icon(this.repeatMode === "one" ? "repeat-one" : "repeat")
    })
  }

  updateFavoriteControls() {
    const favorite = this.currentTrack?.favorite === true
    this.favoriteTargets.forEach((button) => {
      button.hidden = this.offlineMode
      button.classList.toggle("is-active", favorite)
      button.setAttribute("aria-label", favorite ? "Remove from favourites" : "Add to favourites")
      button.innerHTML = this.icon(favorite ? "heart-filled" : "heart")
    })
  }

  updateRadioControls() {
    this.radioTargets.forEach((button) => {
      const eligible = this.currentTrack?.radioEligible === true
      button.hidden = this.offlineMode || !eligible
      button.disabled = this.offlineMode || !eligible
      button.classList.toggle("is-active", eligible && this.radioEnabled)
      const label = this.radioEnabled ? "Radio on" : "Radio off"
      button.setAttribute("aria-label", label)
      button.setAttribute("title", label)
      button.innerHTML = this.icon("radio")
    })
  }

  async toggleQueuedFavorite(index) {
    if (this.offlineMode) return
    const track = this.queue[index]
    if (!track?.source) return

    const favorite = !track.favorite
    const favoriteUrl = track.source.replace(/\/audio\/([^/?]+).*$/, "/favorites/$1")
    const response = await fetch(favoriteUrl, {
      method: "PATCH",
      headers: { Accept: "application/json", "Content-Type": "application/json", "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content },
      body: JSON.stringify({ favorite })
    })
    if (!response.ok) return

    track.favorite = favorite
    if (index === this.currentIndex) this.updateFavoriteControls()
    this.persistQueue({ force: true })
    this.renderQueue()
  }

  addQueuedTrackToPlaylist(index) {
    if (this.offlineMode) return
    const track = this.queue[index]
    const match = track?.source?.match(/^(\/server_connections\/[^/]+)\/audio\/[^/?]+/)
    const cardOptions = this.application.getControllerForElementAndIdentifier(document.body, "card-options")

    if (!track?.itemId || !match || !cardOptions?.openPlaylistPickerForItem) {
      this.showFeedback("Couldn’t open playlists for this track")
      return
    }

    cardOptions.openPlaylistPickerForItem({
      playlistsUrl: `${match[1]}/playlists`,
      itemId: track.itemId,
      itemType: "Audio"
    })
  }

  async downloadQueuedTrack(index, button) {
    const track = this.queue[index]
    if (!track?.source) return

    button.disabled = true
    try {
      const store = new OfflineMediaStore({ scope: document.body.dataset.offlineMediaScopeValue })
      await store.download(track)
      await store.warmOfflineShell()
      this.showFeedback("Available offline")
    } catch (error) {
      this.showFeedback(error.message || "Sonzra couldn’t save this download.")
      button.disabled = false
    }
  }

  removeQueuedTrack(index) {
    if (index < 0 || index >= this.queue.length) return

    const removingCurrent = index === this.currentIndex
    this.queue.splice(index, 1)
    if (this.queue.length === 0) {
      this.clearQueue()
      return
    }

    if (index < this.currentIndex) this.currentIndex -= 1
    if (removingCurrent) {
      this.currentIndex = Math.min(index, this.queue.length - 1)
      this.persistQueue({ force: true })
      this.renderQueue()
      this.playCurrent()
      return
    }

    this.persistQueue({ force: true })
    this.renderQueue()
    this.syncPageTrackControls()
  }

  promptClearQueue() {
    if (!this.hasClearDialogTarget) return

    if (typeof this.clearDialogTarget.showModal === "function") {
      this.clearDialogTarget.showModal()
    } else {
      this.clearDialogTarget.setAttribute("open", "")
    }
  }

  closeClearQueuePrompt() {
    if (!this.hasClearDialogTarget) return

    if (typeof this.clearDialogTarget.close === "function") {
      this.clearDialogTarget.close()
    } else {
      this.clearDialogTarget.removeAttribute("open")
    }
  }

  clearQueue() {
    if (this.radioEnabled) this.setRadioEnabled(false)
    this.queue = []
    this.currentIndex = 0
    this.currentTrack = null
    this.savedPosition = 0
    this.pendingStartPosition = 0
    this.hasReportedStart = false
    this.lastReportedPosition = 0
    this.playbackRequested = false
    this.clearPlaybackRecovery()
    this.audioTarget.pause()
    this.audioTarget.removeAttribute("src")
    this.audioTarget.load()
    this.resetTimeline()
    this.updateFavoriteControls()
    this.updateRadioControls()
    if (this.hasShellTarget) this.shellTarget.hidden = true
    this.persistQueue({ force: true })
    this.renderQueue()
    this.syncPageTrackControls()
    document.title = "Sonzra"
  }

  confirmClearQueue() {
    this.closeClearQueuePrompt()
    this.clearQueue()
  }

  closeClearQueueOnBackdrop(event) {
    if (event.target === this.clearDialogTarget) this.closeClearQueuePrompt()
  }

  setRadioEnabled(enabled, { feedback = null } = {}) {
    this.radioEnabled = enabled
    this.updateRadioControls()
    this.persistQueue({ force: true })
    this.persistPreferences()
    if (feedback) this.showFeedback(feedback)
  }

  resetTimeline() {
    this.timelineTargets.concat(this.expandedTimelineTargets).forEach((timeline) => {
      timeline.max = 0
      timeline.value = 0
    })
    this.updateProgress(0, 0)
    if (this.hasElapsedTarget) this.elapsedTarget.textContent = "0:00"
    if (this.hasDurationTarget) this.durationTarget.textContent = "0:00"
    if (this.hasExpandedElapsedTarget) this.expandedElapsedTarget.textContent = "0:00"
    if (this.hasExpandedDurationTarget) this.expandedDurationTarget.textContent = "0:00"
  }

  formatTime(seconds) {
    const totalSeconds = Math.floor(seconds)
    return `${Math.floor(totalSeconds / 60)}:${String(totalSeconds % 60).padStart(2, "0")}`
  }

  updateProgress(position, duration) {
    const percentage = duration > 0 ? (position / duration) * 100 : 0
    this.timelineTargets.concat(this.expandedTimelineTargets).forEach((timeline) => timeline.style.setProperty("--progress", `${percentage}%`))
    if (this.hasMiniProgressTarget) this.miniProgressTarget.style.width = `${percentage}%`
  }

  stopPlayback() {
    this.playbackRequested = false
    this.clearPlaybackRecovery()
    this.persistQueue({ force: true })
    this.reportPlayback("stopped", { keepalive: true })
  }

  reportPlayback(event, { keepalive = false } = {}) {
    if (this.offlineMode || !this.currentTrack || !this.currentTrack.itemId || !this.currentTrack.reportingUrl || !this.hasAudioTarget) return

    const positionTicks = Math.round(this.audioTarget.currentTime * 10_000_000)
    this.lastReportedPosition = this.audioTarget.currentTime
    if (this.currentTrack.resumable) {
      this.currentTrack.startPosition = this.audioTarget.currentTime
      this.persistQueue({ force: true })
    }
    try {
      fetch(this.currentTrack.reportingUrl, {
        method: "POST",
        headers: {
          Accept: "application/json",
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content
        },
        body: JSON.stringify({ event, item_id: this.currentTrack.itemId, position_ticks: positionTicks, paused: this.audioTarget.paused, resumable: this.currentTrack.resumable && !this.audioTarget.ended }),
        keepalive
      }).catch(() => {})
    } catch (_) {
      // Playback reporting must never interrupt local playback or queue changes.
    }
  }

  restoreVolume() {
    if (!this.hasAudioTarget) return

    const volume = sessionStorage.getItem("sonzra:volume") || "0.8"
    this.audioTarget.volume = volume
  }

  showPlayer() {
    if (this.hasShellTarget) this.shellTarget.hidden = false
  }

  playQueueIndex(index) {
    this.currentIndex = index
    this.persistQueue({ force: true })
    this.renderQueue()
    this.playCurrent()
  }

  showQueueTab() {
    this.setExpandedView("queue")
  }

  async showLyricsTab() {
    if (this.offlineMode) return

    this.setExpandedView("lyrics")
    await this.loadLyrics()
  }

  setExpandedView(view) {
    if (!this.hasQueueViewTarget || !this.hasLyricsViewTarget) return

    const showLyrics = view === "lyrics"
    this.queueViewTarget.hidden = showLyrics
    this.lyricsViewTarget.hidden = !showLyrics
    this.queueTabTarget.classList.toggle("is-active", !showLyrics)
    this.queueTabTarget.setAttribute("aria-selected", String(!showLyrics))
    this.lyricsTabTarget.classList.toggle("is-active", showLyrics)
    this.lyricsTabTarget.setAttribute("aria-selected", String(showLyrics))
  }

  async loadLyrics() {
    const track = this.currentTrack
    const url = this.lyricsUrl(track)
    if (!track?.itemId || !url || !this.hasLyricsStatusTarget) {
      this.showLyricsUnavailable()
      return
    }

    const cachedLyrics = this.lyricsCache.get(track.itemId)
    if (cachedLyrics) {
      this.currentLyrics = cachedLyrics
      this.renderLyrics(cachedLyrics)
      return
    }

    this.lyricsRequest?.abort()
    this.lyricsRequest = new AbortController()
    this.lyricsStatusTarget.hidden = false
    this.lyricsStatusTarget.textContent = "Loading lyrics…"
    this.lyricsListTarget.textContent = ""

    try {
      const response = await fetch(url, { headers: { Accept: "application/json" }, signal: this.lyricsRequest.signal })
      if (!response.ok) throw new Error("Lyrics request failed")

      const lyrics = await response.json()
      if (this.currentTrack !== track) return

      this.lyricsCache.set(track.itemId, lyrics)
      this.currentLyrics = lyrics
      this.renderLyrics(lyrics)
    } catch (error) {
      if (error.name === "AbortError" || this.currentTrack !== track) return

      this.showLyricsUnavailable("Lyrics could not be loaded for this track.")
    }
  }

  lyricsUrl(track) {
    const match = track?.source?.match(/^(\/server_connections\/[^/]+)\/audio\/([^/?]+)/)
    return match ? `${match[1]}/lyrics/${match[2]}` : null
  }

  resetLyricsView() {
    if (!this.hasLyricsStatusTarget) return

    this.lyricsStatusTarget.hidden = false
    this.lyricsStatusTarget.textContent = "Open Lyrics to load the words for this track."
    if (this.hasLyricsListTarget) this.lyricsListTarget.textContent = ""
    if (this.hasLyricsFollowTarget) this.lyricsFollowTarget.hidden = true
  }

  showLyricsUnavailable(message = "Lyrics aren’t available for this track.") {
    this.currentLyrics = null
    if (this.hasLyricsStatusTarget) {
      this.lyricsStatusTarget.hidden = false
      this.lyricsStatusTarget.textContent = message
    }
    if (this.hasLyricsListTarget) this.lyricsListTarget.textContent = ""
    if (this.hasLyricsFollowTarget) this.lyricsFollowTarget.hidden = true
  }

  renderLyrics(lyrics) {
    const lines = Array.isArray(lyrics?.lines) ? lyrics.lines : []
    if (!lyrics?.available || lines.length === 0) {
      this.showLyricsUnavailable()
      return
    }

    this.lyricsStatusTarget.hidden = true
    this.lyricsListTarget.textContent = ""
    lines.forEach((line, index) => {
      const item = document.createElement("li")
      item.className = "listen-queue__lyric-group"
      line.text.split(/\r?\n/).filter(Boolean).forEach((textValue) => {
        const text = document.createElement("span")
        text.className = "listen-queue__lyric-line"
        text.textContent = textValue
        item.appendChild(text)
      })
      if (line.start !== null && line.start !== undefined && Number.isFinite(Number(line.start))) {
        item.classList.add("is-timed")
        item.tabIndex = 0
        item.setAttribute("role", "button")
        item.setAttribute("aria-label", `Play from ${this.formatTime(Number(line.start))}: ${line.text}`)
        item.addEventListener("click", () => this.seekLyricsLine(index))
        item.addEventListener("keydown", (event) => {
          if ([ "Enter", " " ].includes(event.key)) {
            event.preventDefault()
            this.seekLyricsLine(index)
          }
        })
      }
      this.lyricsListTarget.appendChild(item)
    })
    this.updateActiveLyric()
  }

  seekLyricsLine(index) {
    const line = this.currentLyrics?.lines?.[index]
    if (line?.start === null || line?.start === undefined || !Number.isFinite(Number(line.start))) return

    this.audioTarget.currentTime = Number(line.start)
    this.lyricsFollowing = true
    if (this.hasLyricsFollowTarget) this.lyricsFollowTarget.hidden = true
    this.updateTimeline()
  }

  updateActiveLyric() {
    const lines = this.currentLyrics?.lines
    if (!this.currentLyrics?.synchronized || !Array.isArray(lines) || !this.hasLyricsListTarget) return

    const position = Number(this.audioTarget.currentTime) || 0
    const index = lines.reduce((activeIndex, line, currentIndex) => Number(line.start) <= position ? currentIndex : activeIndex, -1)
    if (index === this.activeLyricIndex) return

    this.activeLyricIndex = index
    Array.from(this.lyricsListTarget.children).forEach((line, lineIndex) => {
      line.classList.remove("is-current")
      line.classList.toggle("is-current-lyric", lineIndex === index)
    })
    if (index < 0 || !this.lyricsFollowing || this.lyricsViewTarget.hidden) return

    const activeLine = this.lyricsListTarget.children[index]
    if (!activeLine) return

    this.followingLyricScroll = true
    activeLine.scrollIntoView({ block: "center", behavior: "smooth" })
    window.clearTimeout(this.lyricScrollTimeout)
    this.lyricScrollTimeout = window.setTimeout(() => { this.followingLyricScroll = false }, 700)
  }

  pauseLyricsFollow() {
    if (this.followingLyricScroll || !this.currentLyrics?.synchronized) return

    this.lyricsFollowing = false
    if (this.hasLyricsFollowTarget) this.lyricsFollowTarget.hidden = false
  }

  followLyrics() {
    this.lyricsFollowing = true
    if (this.hasLyricsFollowTarget) this.lyricsFollowTarget.hidden = true
    this.activeLyricIndex = null
    this.updateActiveLyric()
  }

  openQueue() {
    window.clearTimeout(this.queueCloseTimeout)
    window.cancelAnimationFrame(this.queueOpenFrame)
    this.queuePanelTarget.hidden = false
    this.queuePanelTarget.classList.remove("is-closing")
    this.showQueueTab()
    this.queueOpenFrame = window.requestAnimationFrame(() => this.queuePanelTarget.classList.add("is-open"))
    this.persistQueue({ force: true })
  }

  closeQueue() {
    window.cancelAnimationFrame(this.queueOpenFrame)
    this.queuePanelTarget.classList.remove("is-open")
    this.queuePanelTarget.classList.add("is-closing")
    window.clearTimeout(this.queueCloseTimeout)
    this.queueCloseTimeout = window.setTimeout(() => {
      this.queuePanelTarget.hidden = true
      this.queuePanelTarget.classList.remove("is-closing")
    }, 180)
    this.persistQueue({ force: true })
  }

  showQueueFeedback(tracks) {
    const message = tracks.length === 1 ? `Added “${tracks[0].title}” to queue` : `Added ${tracks.length} tracks to queue`
    this.showFeedback(message)
  }

  async maybeExtendRadioQueue({ force = false } = {}) {
    if (this.offlineMode) return

    if (!this.radioEnabled || !this.currentTrack?.radioEligible || !this.currentTrack?.radioUrl || this.loadingRadioQueue) return

    const remainingTracks = this.queue.length - this.currentIndex - 1
    const queueCapacity = Math.max(0, RADIO_MAX_QUEUE_SIZE - this.queue.length)
    const neededTracks = Math.min(RADIO_TARGET_AHEAD - remainingTracks, queueCapacity)
    if (!force && remainingTracks > RADIO_TOP_UP_THRESHOLD) return
    if (neededTracks <= 0) return
    const requestKey = `${this.currentTrack.itemId}:${this.currentIndex}:${this.queue.length}`
    if (!force && this.lastRadioRequestKey === requestKey) return

    this.lastRadioRequestKey = requestKey
    this.loadingRadioQueue = true
    try {
      const separator = this.currentTrack.radioUrl.includes("?") ? "&" : "?"
      const response = await fetch(`${this.currentTrack.radioUrl}${separator}limit=${neededTracks}`, { headers: { Accept: "application/json" } })
      if (!response.ok) return

      const payload = await response.json()
      const knownIds = new Set(this.queue.map((track) => track.itemId))
      const additions = (payload.items || [])
        .map((track) => this.normalizeTrack({
          ...track,
          itemId: track.item_id,
          reportingUrl: track.reporting_url,
          radioUrl: track.radio_url,
          radioEligible: track.radio_eligible
        }))
        .filter((track) => track.itemId && !knownIds.has(track.itemId))

      if (additions.length === 0) return

      this.queue.push(...additions)
      this.trimQueueHistory()
      this.persistQueue({ force: true })
      this.renderQueue()
    } catch (_) {
      // Radio is opportunistic. Failing to fetch recommendations must not break playback.
    } finally {
      this.loadingRadioQueue = false
    }
  }

  trimQueueHistory() {
    const keepFromIndex = Math.max(0, this.currentIndex - 3)
    if (keepFromIndex > 0) {
      this.queue = this.queue.slice(keepFromIndex)
      this.currentIndex -= keepFromIndex
    }

    if (this.queue.length > RADIO_MAX_QUEUE_SIZE) this.queue = this.queue.slice(0, RADIO_MAX_QUEUE_SIZE)
  }

  async persistPreferences() {
    if (this.offlineMode || !this.hasPreferencesUrlValue) return

    try {
      await fetch(this.preferencesUrlValue, {
        method: "PATCH",
        headers: {
          Accept: "application/json",
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content
        },
        body: JSON.stringify({ radio_enabled: this.radioEnabled })
      })
    } catch (_) {
      // Preference sync is best effort only.
    }
  }

  normalizeTrack(track) {
    return {
      ...track,
      favorite: track.favorite === true || track.favorite === "true",
      radioEligible: track.radioEligible === true || track.radioEligible === "true",
      radioUrl: track.radioUrl || this.fallbackRadioUrl(track),
      resumable: track.resumable === true || track.resumable === "true"
    }
  }

  fallbackRadioUrl(track) {
    if (!track.itemId || !track.source || track.resumable) return null

    const match = track.source.match(/^(\/server_connections\/[^/]+)\/audio\/[^/?]+/)
    return match ? `${match[1]}/radio_tracks/${track.itemId}` : null
  }

  showFeedback(message) {
    if (!this.hasQueueFeedbackTarget) return

    window.clearTimeout(this.queueFeedbackTimeout)
    window.clearTimeout(this.queueFeedbackHideTimeout)
    this.queueFeedbackTarget.textContent = message
    this.queueFeedbackTarget.hidden = false
    window.requestAnimationFrame(() => this.queueFeedbackTarget.classList.add("is-visible"))
    this.queueFeedbackTimeout = window.setTimeout(() => {
      this.queueFeedbackTarget.classList.remove("is-visible")
      this.queueFeedbackHideTimeout = window.setTimeout(() => { this.queueFeedbackTarget.hidden = true }, 180)
    }, 2400)
  }

  monitorPlayback(playback) {
    if (!playback) return

    playback.then(() => {
      // A Turbo-permanent audio element can outlive its controller while a
      // native WebView restores a page. The audio can then play before the
      // replacement controller receives its `play` event. The resolved
      // promise gives us a dependable second path to keep the player UI in
      // sync without duplicating normal event-driven updates.
      if (!this.progressWatch) this.handlePlay()
    }).catch(this.boundHandlePlaybackError)
  }

  relocateLegacyQueue() {
    const legacyQueue = document.querySelector("#player .listen-queue")
    if (!legacyQueue) return

    if (document.querySelector("body > #player-queue")) {
      legacyQueue.remove()
    } else {
      document.body.append(legacyQueue)
    }
  }

  bindEventHandlers() {
    this.boundUpdateTimeline = this.updateTimeline.bind(this)
    this.boundHandlePlay = this.handlePlay.bind(this)
    this.boundHandlePause = this.handlePause.bind(this)
    this.boundReportProgress = this.reportProgress.bind(this)
    this.boundPlayNext = this.playNext.bind(this)
    this.boundHandleBuffering = this.handleBuffering.bind(this)
    this.boundHandleCanPlay = this.handleCanPlay.bind(this)
    this.boundHandlePlaybackError = this.handlePlaybackError.bind(this)
    this.boundHandlePageHide = this.handlePageHide.bind(this)
    this.boundReconcilePlayback = this.reconcilePlayback.bind(this)
    this.boundHandleVisibilityChange = this.handleVisibilityChange.bind(this)
    this.boundHandleNativeMediaCommand = this.handleNativeMediaCommand.bind(this)
    this.boundSyncPageTrackControls = this.syncPageTrackControls.bind(this)
  }

  startProgressWatch() {
    this.stopProgressWatch()
    this.progressWatch = window.setInterval(this.boundReconcilePlayback, 1000)
  }

  stopProgressWatch() {
    if (!this.progressWatch) return

    window.clearInterval(this.progressWatch)
    this.progressWatch = null
  }

  reconcilePlayback() {
    if (!this.hasAudioTarget) return

    this.updateTimeline()
    this.maybeExtendRadioQueue()
    const duration = this.audioTarget.duration
    const finished = this.audioTarget.ended || (Number.isFinite(duration) && duration > 0 && this.audioTarget.currentTime >= duration - 0.05)
    if (finished) this.playNext()
  }

  handlePageHide() {
    this.persistQueue({ force: true })
    this.reportPlayback("progress", { keepalive: true })
  }

  handleVisibilityChange() {
    if (document.visibilityState === "hidden") {
      this.persistQueue({ force: true })
      this.reportPlayback("progress", { keepalive: true })
      return
    }

    this.reconcilePlayback()
  }

  handleNativeMediaCommand(event) {
    switch (event.detail?.command) {
      case "play":
      case "pause":
        this.toggle()
        break
      case "next":
        this.next()
        break
      case "previous":
        this.previous()
        break
    }
  }

  syncNativeMedia() {
    if (!this.currentTrack || !this.hasAudioTarget || !window.SonzraNativeMedia?.update) return

    try {
      const artwork = new URL(this.currentTrack.artwork || "/brand/sonzra-mark.svg", window.location.origin).href
      window.SonzraNativeMedia.update(
        this.currentTrack.title || "Sonzra",
        this.currentTrack.artist || "",
        artwork,
        !this.audioTarget.paused,
        Number(this.audioTarget.currentTime) || 0,
        Number(this.audioTarget.duration) || 0
      )
    } catch (_) {
      // The browser version has no native bridge, and playback must remain unaffected.
    }
  }

  syncBrowserMedia() {
    if (!this.currentTrack) return

    const title = this.currentTrack.title || "Sonzra"
    const artist = this.currentTrack.artist || ""
    document.title = artist ? `${title} · ${artist} | Sonzra` : `${title} | Sonzra`

    const mediaSession = navigator.mediaSession
    if (!mediaSession || typeof MediaMetadata === "undefined") return

    try {
      const artwork = new URL(this.currentTrack.artwork || "/brand/sonzra-mark.svg", window.location.origin).href
      mediaSession.metadata = new MediaMetadata({ title, artist, artwork: [ { src: artwork } ] })
      mediaSession.playbackState = this.audioTarget?.paused ? "paused" : "playing"
      mediaSession.setActionHandler("play", () => this.toggle())
      mediaSession.setActionHandler("pause", () => this.toggle())
      mediaSession.setActionHandler("previoustrack", () => this.previous())
      mediaSession.setActionHandler("nexttrack", () => this.next())
      this.syncBrowserMediaPosition()
    } catch (_) {
      // Media Session support differs across browsers and must remain optional.
    }
  }

  syncBrowserMediaPosition() {
    const mediaSession = navigator.mediaSession
    const duration = Number(this.audioTarget?.duration)
    if (!mediaSession?.setPositionState || !Number.isFinite(duration) || duration <= 0) return

    try {
      mediaSession.setPositionState({
        duration,
        playbackRate: this.audioTarget.playbackRate || 1,
        position: Math.min(Math.max(Number(this.audioTarget.currentTime) || 0, 0), duration)
      })
    } catch (_) {
      // Browsers may reject incomplete or unsupported media-session state.
    }
  }

  configureAudioSession() {
    if (!navigator.audioSession) return

    try {
      navigator.audioSession.type = "playback"
    } catch (_) {
      // Audio Session is optional; unsupported browsers use HTML audio normally.
    }
  }

  syncPageTrackControls() {
    const currentItemId = this.currentTrack?.itemId
    document.querySelectorAll(".track-list .listen-card__play[data-player-item-id-param]").forEach((button) => {
      const isCurrent = currentItemId && button.dataset.playerItemIdParam === currentItemId
      button.classList.toggle("is-current", Boolean(isCurrent))
      button.closest("li")?.classList.toggle("is-playing", Boolean(isCurrent))
      if (isCurrent) {
        const isPaused = this.audioTarget?.paused
        button.dataset.action = "player#toggle"
        button.setAttribute("aria-label", `${isPaused ? "Play" : "Pause"} ${this.currentTrack.title}`)
        button.innerHTML = this.icon(isPaused ? "play" : "pause")
      } else {
        button.dataset.action = "player#replaceQueue"
        button.setAttribute("aria-label", `Play ${button.dataset.playerTitleParam}`)
        button.innerHTML = this.icon("play")
      }
    })
  }

  icon(name, className = "") {
    const paths = {
      play: '<polygon points="5 3 19 12 5 21 5 3"></polygon>',
      pause: '<rect x="6" y="4" width="4" height="16"></rect><rect x="14" y="4" width="4" height="16"></rect>',
      repeat: '<path d="m17 1 4 4-4 4"></path><path d="M3 11V9a4 4 0 0 1 4-4h14"></path><path d="m7 23-4-4 4-4"></path><path d="M21 13v2a4 4 0 0 1-4 4H3"></path>',
      "repeat-one": '<path d="m17 1 4 4-4 4"></path><path d="M3 11V9a4 4 0 0 1 4-4h14"></path><path d="m7 23-4-4 4-4"></path><path d="M21 13v2a4 4 0 0 1-4 4H3"></path><path d="M11 10h1v4"></path><path d="M12 14h-1"></path>'
      , x: '<path d="M18 6 6 18"></path><path d="m6 6 12 12"></path>'
      , heart: '<path d="M20.8 4.6a5.5 5.5 0 0 0-7.8 0L12 5.7l-1.1-1.1a5.5 5.5 0 0 0-7.8 7.8L12 21l8.9-8.6a5.5 5.5 0 0 0-.1-7.8Z"></path>',
      "heart-filled": '<path fill="currentColor" d="M20.8 4.6a5.5 5.5 0 0 0-7.8 0L12 5.7l-1.1-1.1a5.5 5.5 0 0 0-7.8 7.8L12 21l8.9-8.6a5.5 5.5 0 0 0-.1-7.8Z"></path>',
      radio: '<path d="M4.9 8.9a10 10 0 0 1 14.2 0"></path><path d="M7.8 11.8a6 6 0 0 1 8.4 0"></path><path d="M10.7 14.7a2 2 0 0 1 2.6 0"></path><path d="M12 16v5"></path><circle cx="12" cy="18" r="1"></circle>'
      , ellipsis: '<circle cx="5" cy="12" r="1.5" fill="currentColor"></circle><circle cx="12" cy="12" r="1.5" fill="currentColor"></circle><circle cx="19" cy="12" r="1.5" fill="currentColor"></circle>'
      , "list-plus": '<path d="M11 12H3"></path><path d="M16 6H3"></path><path d="M16 18H3"></path><path d="M18 9v6"></path><path d="M21 12h-6"></path>'
      , download: '<path d="M12 3v12"></path><path d="m7 10 5 5 5-5"></path><path d="M5 21h14"></path>'
    }
    return `<svg class="${className}" viewBox="0 0 24 24" aria-hidden="true" focusable="false">${paths[name]}</svg>`
  }
}
