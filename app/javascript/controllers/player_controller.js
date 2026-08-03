import { Controller } from "@hotwired/stimulus"

const PLAYER_STATE_KEY = "sonzra:player-state"
const LEGACY_QUEUE_KEY = "sonzra:queue"
const LEGACY_QUEUE_INDEX_KEY = "sonzra:queue-index"

export default class extends Controller {
  static targets = ["shell", "audio", "artwork", "title", "artist", "toggle", "timeline", "elapsed", "duration", "miniProgress", "queuePanel", "queueList", "queueFeedback", "expandedArtwork", "expandedTitle", "expandedArtist", "expandedToggle", "expandedTimeline", "expandedElapsed", "expandedDuration"]

  connect() {
    // The player is Turbo-permanent. During a deploy or a Turbo restoration it
    // can briefly retain markup from an older version of the component.
    // Do not let that incomplete markup prevent the page from connecting.
    if (!this.hasAudioTarget) return

    this.relocateLegacyQueue()
    this.restoreVolume()
    this.restoreQueue()
    this.audioTarget.preload = "auto"
    this.audioTarget.playsInline = true
    this.bindEventHandlers()
    this.audioTarget.addEventListener("timeupdate", this.boundUpdateTimeline)
    this.audioTarget.addEventListener("loadedmetadata", this.boundUpdateTimeline)
    this.audioTarget.addEventListener("durationchange", this.boundUpdateTimeline)
    this.audioTarget.addEventListener("canplay", this.boundUpdateTimeline)
    this.audioTarget.addEventListener("play", this.boundHandlePlay)
    this.audioTarget.addEventListener("pause", this.boundHandlePause)
    this.audioTarget.addEventListener("seeked", this.boundReportProgress)
    this.audioTarget.addEventListener("ended", this.boundPlayNext)
    this.audioTarget.addEventListener("error", this.boundShowPlaybackError)
    window.addEventListener("pagehide", this.boundStopPlayback)
    window.addEventListener("pageshow", this.boundReconcilePlayback)
    window.addEventListener("sonzra:native-media-command", this.boundHandleNativeMediaCommand)
    document.addEventListener("visibilitychange", this.boundReconcilePlayback)
    document.addEventListener("turbo:load", this.boundSyncPageTrackControls)
    this.reconcilePlayback()
    this.syncPageTrackControls()
  }

  disconnect() {
    if (!this.hasAudioTarget) return

    this.persistQueue({ force: true })
    this.audioTarget.removeEventListener("timeupdate", this.boundUpdateTimeline)
    this.audioTarget.removeEventListener("loadedmetadata", this.boundUpdateTimeline)
    this.audioTarget.removeEventListener("durationchange", this.boundUpdateTimeline)
    this.audioTarget.removeEventListener("canplay", this.boundUpdateTimeline)
    this.audioTarget.removeEventListener("play", this.boundHandlePlay)
    this.audioTarget.removeEventListener("pause", this.boundHandlePause)
    this.audioTarget.removeEventListener("seeked", this.boundReportProgress)
    this.audioTarget.removeEventListener("ended", this.boundPlayNext)
    this.audioTarget.removeEventListener("error", this.boundShowPlaybackError)
    window.removeEventListener("pagehide", this.boundStopPlayback)
    window.removeEventListener("pageshow", this.boundReconcilePlayback)
    window.removeEventListener("sonzra:native-media-command", this.boundHandleNativeMediaCommand)
    document.removeEventListener("visibilitychange", this.boundReconcilePlayback)
    document.removeEventListener("turbo:load", this.boundSyncPageTrackControls)
    this.stopProgressWatch()
  }

  async replaceQueue(event) {
    const tracks = await this.tracksFor(event)
    if (tracks.length === 0) return

    this.queue = tracks
    this.currentIndex = 0
    this.persistQueue({ force: true })
    this.renderQueue()
    this.playCurrent()
  }

  async appendQueue(event) {
    const tracks = await this.tracksFor(event)
    if (tracks.length === 0) return

    this.queue.push(...tracks)
    this.persistQueue({ force: true })
    this.renderQueue()
    this.showQueueFeedback(tracks)
    if (!this.audioTarget.src) this.playCurrent()
  }

  toggle() {
    if (!this.audioTarget.src) return

    if (this.audioTarget.paused) {
      const playback = this.audioTarget.play()
      this.monitorPlayback(playback)
    } else {
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
    if (this.hasDurationTarget) this.durationTarget.textContent = this.formatTime(duration)
    if (this.hasExpandedElapsedTarget) this.expandedElapsedTarget.textContent = this.formatTime(this.audioTarget.currentTime)
    if (this.hasExpandedDurationTarget) this.expandedDurationTarget.textContent = this.formatTime(duration)
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
    if (this.hasReportedStart) {
      this.reportPlayback("stopped")
      this.hasReportedStart = false
    }
    this.persistQueue({ force: true })
  }

  reportProgress() {
    this.reportPlayback("progress")
  }

  playNext() {
    if (this.advancingQueue) return

    this.advancingQueue = true
    if (this.currentIndex >= this.queue.length - 1) {
      this.stopPlayback()
      this.advancingQueue = false
      return
    }

    this.playQueueIndex(this.currentIndex + 1)
    this.advancingQueue = false
  }

  showPlaybackError() {
    if (this.hasArtistTarget) this.artistTarget.textContent = "This track could not be played. Check the server logs and try again."
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
        reportingUrl: track.reporting_url
      }))
    } catch (_) {
      return []
    }
  }

  trackFrom({ source, title, artist, artwork, duration, itemId, reportingUrl, startPosition, resumable }) {
    return { source, title, artist, artwork, duration, itemId, reportingUrl, startPosition, resumable: resumable === true || resumable === "true" }
  }

  playCurrent() {
    const track = this.queue[this.currentIndex]
    if (!track) return

    if (this.currentTrack && this.currentTrack !== track) this.reportPlayback("stopped")
    this.loadTrack(track)
    const playback = this.audioTarget.play()
    this.monitorPlayback(playback)
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
    this.currentTrack = track
    this.hasReportedStart = false
    this.lastReportedPosition = 0
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
    this.syncNativeMedia()
    this.syncBrowserMedia()
    this.syncPageTrackControls()
  }

  restoreQueue() {
    const savedState = this.readPersistedState()
    try {
      this.queue = Array.isArray(savedState.queue) ? savedState.queue : []
      this.currentIndex = Math.min(Math.max(Number(savedState.currentIndex) || 0, 0), Math.max(this.queue.length - 1, 0))
      this.savedPosition = Number(savedState.position) || 0
      this.queueWasOpen = savedState.queueOpen === true
    } catch (_) {
      this.queue = []
      this.currentIndex = 0
      this.savedPosition = 0
      this.queueWasOpen = false
    }
    this.renderQueue()
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
        queueOpen: false
      }
    } catch (_) {
      return { queue: [], currentIndex: 0, position: 0, queueOpen: false }
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
        queueOpen: this.hasQueuePanelTarget && !this.queuePanelTarget.hidden && !this.queuePanelTarget.classList.contains("is-closing")
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
      const details = document.createElement("span")
      details.textContent = `${track.title} — ${track.artist}`
      const duration = document.createElement("time")
      duration.textContent = track.duration || "—"
      const playButton = document.createElement("button")
      playButton.type = "button"
      const isCurrent = queueIndex === this.currentIndex
      playButton.ariaLabel = `Play ${track.title}`
      playButton.innerHTML = this.icon("play", "listen-queue__item-play-icon")
      playButton.className = "listen-queue__item-play"
      playButton.classList.toggle("is-current", isCurrent)
      playButton.addEventListener("click", () => this.playQueueIndex(queueIndex))
      item.append(artwork, details, duration, playButton)
      this.queueListTarget.appendChild(item)
    })
    if (this.queue.length === 0) this.queueListTarget.textContent = "Nothing queued"
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
    this.persistQueue({ force: true })
    this.reportPlayback("stopped", { keepalive: true })
  }

  reportPlayback(event, { keepalive = false } = {}) {
    if (!this.currentTrack || !this.currentTrack.itemId || !this.currentTrack.reportingUrl || !this.hasAudioTarget) return

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

  openQueue() {
    window.clearTimeout(this.queueCloseTimeout)
    window.cancelAnimationFrame(this.queueOpenFrame)
    this.queuePanelTarget.hidden = false
    this.queuePanelTarget.classList.remove("is-closing")
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
    if (!this.hasQueueFeedbackTarget) return

    const message = tracks.length === 1 ? `Added “${tracks[0].title}” to queue` : `Added ${tracks.length} tracks to queue`
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
    }).catch(this.boundShowPlaybackError)
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
    this.boundShowPlaybackError = this.showPlaybackError.bind(this)
    this.boundStopPlayback = this.stopPlayback.bind(this)
    this.boundReconcilePlayback = this.reconcilePlayback.bind(this)
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
    const duration = this.audioTarget.duration
    const finished = this.audioTarget.ended || (Number.isFinite(duration) && duration > 0 && this.audioTarget.currentTime >= duration - 0.05)
    if (finished) this.playNext()
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
    } catch (_) {
      // Media Session support differs across browsers and must remain optional.
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
      pause: '<rect x="6" y="4" width="4" height="16"></rect><rect x="14" y="4" width="4" height="16"></rect>'
    }
    return `<svg class="${className}" viewBox="0 0 24 24" aria-hidden="true" focusable="false">${paths[name]}</svg>`
  }
}
