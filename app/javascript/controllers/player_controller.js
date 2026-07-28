import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["audio", "artwork", "title", "artist", "toggle", "timeline", "elapsed", "duration", "volume", "queuePanel", "queueList", "expandedArtwork", "expandedTitle", "expandedArtist", "expandedToggle", "expandedTimeline", "expandedElapsed", "expandedDuration"]

  connect() {
    // The player is Turbo-permanent. During a deploy or a Turbo restoration it
    // can briefly retain markup from an older version of the component.
    // Do not let that incomplete markup prevent the page from connecting.
    if (!this.hasAudioTarget) return

    this.relocateLegacyQueue()
    this.restoreVolume()
    this.restoreQueue()
    this.audioTarget.addEventListener("timeupdate", this.updateTimeline)
    this.audioTarget.addEventListener("loadedmetadata", this.updateTimeline)
    this.audioTarget.addEventListener("durationchange", this.updateTimeline)
    this.audioTarget.addEventListener("play", this.handlePlay)
    this.audioTarget.addEventListener("pause", this.handlePause)
    this.audioTarget.addEventListener("seeked", this.reportProgress)
    this.audioTarget.addEventListener("ended", this.playNext)
    this.audioTarget.addEventListener("error", this.showPlaybackError)
    window.addEventListener("pagehide", this.stopPlayback)
  }

  disconnect() {
    if (!this.hasAudioTarget) return

    this.audioTarget.removeEventListener("timeupdate", this.updateTimeline)
    this.audioTarget.removeEventListener("loadedmetadata", this.updateTimeline)
    this.audioTarget.removeEventListener("durationchange", this.updateTimeline)
    this.audioTarget.removeEventListener("play", this.handlePlay)
    this.audioTarget.removeEventListener("pause", this.handlePause)
    this.audioTarget.removeEventListener("seeked", this.reportProgress)
    this.audioTarget.removeEventListener("ended", this.playNext)
    this.audioTarget.removeEventListener("error", this.showPlaybackError)
    window.removeEventListener("pagehide", this.stopPlayback)
  }

  async replaceQueue(event) {
    const tracks = await this.tracksFor(event)
    if (tracks.length === 0) return

    this.queue = tracks
    this.currentIndex = 0
    this.persistQueue()
    this.renderQueue()
    this.playCurrent()
  }

  async appendQueue(event) {
    const tracks = await this.tracksFor(event)
    if (tracks.length === 0) return

    this.queue.push(...tracks)
    this.persistQueue()
    this.renderQueue()
    if (!this.audioTarget.src) this.playCurrent()
  }

  toggle() {
    if (!this.audioTarget.src) return

    this.audioTarget.paused ? this.audioTarget.play().catch(this.showPlaybackError) : this.audioTarget.pause()
  }

  seek(event) {
    this.audioTarget.currentTime = event.currentTarget.value
    this.updateProgress(Number(event.currentTarget.value), Number(event.currentTarget.max))
  }

  setVolume() {
    if (!this.hasVolumeTarget) return

    this.audioTarget.volume = this.volumeTarget.value
    sessionStorage.setItem("sonzra:volume", this.volumeTarget.value)
  }

  toggleQueue() {
    this.relocateLegacyQueue()
    const opening = this.queuePanelTarget.hidden
    this.queuePanelTarget.hidden = !opening

    if (opening) {
      const compactLayout = window.matchMedia("(max-width: 1120px)").matches
      Object.assign(this.queuePanelTarget.style, {
        position: "fixed",
        zIndex: "9999",
        inset: "0",
        display: "grid",
        gridTemplateColumns: compactLayout ? "1fr" : "minmax(320px, 1fr) minmax(340px, .9fr)",
        gridTemplateRows: compactLayout ? "auto minmax(0, 1fr)" : "none",
        gap: compactLayout ? "24px" : "clamp(34px, 6vw, 108px)",
        alignItems: "center",
        padding: compactLayout ? "64px 28px 24px" : "clamp(28px, 6vw, 88px)",
        background: "radial-gradient(circle at 24% 20%, #7a5af82e, transparent 30%), linear-gradient(135deg, #0b0b14, #171526 58%, #101923)"
      })
    } else {
      this.queuePanelTarget.style.display = "none"
    }
  }

  previous() {
    if (this.currentIndex === 0) return

    this.currentIndex -= 1
    this.persistQueue()
    this.renderQueue()
    this.playCurrent()
  }

  next() {
    if (this.currentIndex >= this.queue.length - 1) return

    this.currentIndex += 1
    this.persistQueue()
    this.renderQueue()
    this.playCurrent()
  }

  updateTimeline = () => {
    const duration = this.audioTarget.duration
    if (this.hasElapsedTarget) this.elapsedTarget.textContent = this.formatTime(this.audioTarget.currentTime)
    if (!Number.isFinite(duration)) return

    this.timelineTargets.concat(this.expandedTimelineTargets).forEach((timeline) => {
      timeline.max = duration
      timeline.value = this.audioTarget.currentTime
    })
    this.updateProgress(this.audioTarget.currentTime, duration)
    if (this.hasDurationTarget) this.durationTarget.textContent = this.formatTime(duration)
    if (this.hasExpandedElapsedTarget) this.expandedElapsedTarget.textContent = this.formatTime(this.audioTarget.currentTime)
    if (this.hasExpandedDurationTarget) this.expandedDurationTarget.textContent = this.formatTime(duration)
    if (this.audioTarget.currentTime - (this.lastReportedPosition || 0) >= 15) this.reportProgress()
  }

  updateToggle = () => {
    const icon = this.audioTarget.paused ? "▶" : "⏸"
    const label = this.audioTarget.paused ? "Play" : "Pause"
    this.toggleTargets.concat(this.expandedToggleTargets).forEach((button) => {
      button.textContent = icon
      button.setAttribute("aria-label", label)
    })
  }

  handlePlay = () => {
    this.updateToggle()
    this.reportPlayback(this.hasReportedStart ? "progress" : "started")
    this.hasReportedStart = true
  }

  handlePause = () => {
    this.updateToggle()
    this.reportPlayback("progress")
  }

  reportProgress = () => this.reportPlayback("progress")

  playNext = () => {
    if (this.currentIndex >= this.queue.length - 1) return this.stopPlayback()

    this.playQueueIndex(this.currentIndex + 1)
  }

  showPlaybackError = () => {
    this.artistTarget.textContent = "This track could not be played. Check the server logs and try again."
  }

  async tracksFor(event) {
    if (!event.params.queueUrl) return [ this.trackFrom(event.params) ]

    const response = await fetch(event.params.queueUrl, { headers: { Accept: "application/json" } })
    if (!response.ok) return []

    return (await response.json()).items.map((track) => ({
      ...track,
      itemId: track.item_id,
      reportingUrl: track.reporting_url
    }))
  }

  trackFrom({ source, title, artist, artwork, duration, itemId, reportingUrl }) {
    return { source, title, artist, artwork, duration, itemId, reportingUrl }
  }

  playCurrent() {
    const track = this.queue[this.currentIndex]
    if (!track) return

    if (this.currentTrack && this.currentTrack !== track) this.reportPlayback("stopped")
    this.loadTrack(track)
    this.audioTarget.play().catch(this.showPlaybackError)
  }

  restoreCurrentTrack() {
    const track = this.queue[this.currentIndex]
    if (!track || this.audioTarget.src) return

    this.loadTrack(track)
    this.audioTarget.pause()
  }

  loadTrack(track) {
    this.currentTrack = track
    this.hasReportedStart = false
    this.lastReportedPosition = 0
    this.audioTarget.src = track.source
    this.titleTarget.textContent = track.title
    this.artistTarget.textContent = track.artist
    this.artworkTarget.src = track.artwork
    if (this.hasExpandedTitleTarget) this.expandedTitleTarget.textContent = track.title
    if (this.hasExpandedArtistTarget) this.expandedArtistTarget.textContent = track.artist
    if (this.hasExpandedArtworkTarget) this.expandedArtworkTarget.src = track.artwork
    this.resetTimeline()
  }

  restoreQueue() {
    const savedQueue = sessionStorage.getItem("sonzra:queue")
    const savedIndex = sessionStorage.getItem("sonzra:queue-index")
    this.queue = savedQueue ? JSON.parse(savedQueue) : []
    this.currentIndex = savedIndex ? Number(savedIndex) : 0
    this.renderQueue()
    this.restoreCurrentTrack()
  }

  persistQueue() {
    sessionStorage.setItem("sonzra:queue", JSON.stringify(this.queue))
    sessionStorage.setItem("sonzra:queue-index", this.currentIndex)
  }

  renderQueue() {
    const firstVisibleIndex = Math.max(0, this.currentIndex - 3)
    this.queueListTarget.replaceChildren(...this.queue.slice(firstVisibleIndex).map((track, index) => {
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
      playButton.ariaLabel = `Play ${track.title}`
      playButton.textContent = "▶"
      playButton.addEventListener("click", () => this.playQueueIndex(queueIndex))
      item.append(artwork, details, duration, playButton)
      return item
    }))
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
  }

  stopPlayback = () => this.reportPlayback("stopped", { keepalive: true })

  reportPlayback(event, { keepalive = false } = {}) {
    if (!this.currentTrack?.itemId || !this.currentTrack?.reportingUrl || !this.hasAudioTarget) return

    const positionTicks = Math.round(this.audioTarget.currentTime * 10_000_000)
    this.lastReportedPosition = this.audioTarget.currentTime
    try {
      fetch(this.currentTrack.reportingUrl, {
        method: "POST",
        headers: {
          Accept: "application/json",
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content
        },
        body: JSON.stringify({ event, item_id: this.currentTrack.itemId, position_ticks: positionTicks, paused: this.audioTarget.paused }),
        keepalive
      }).catch(() => {})
    } catch (_) {
      // Playback reporting must never interrupt local playback or queue changes.
    }
  }

  restoreVolume() {
    if (!this.hasAudioTarget || !this.hasVolumeTarget) return

    const volume = sessionStorage.getItem("sonzra:volume") || this.volumeTarget.value
    this.volumeTarget.value = volume
    this.audioTarget.volume = volume
  }

  playQueueIndex(index) {
    this.currentIndex = index
    this.persistQueue()
    this.renderQueue()
    this.playCurrent()
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
}
