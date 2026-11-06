import { Application } from "@hotwired/stimulus"
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import PlayerController from "../../app/javascript/controllers/player_controller.js"

describe("player controller", () => {
  let application
  let controller
  let persistedStorage

  beforeEach(async () => {
    sessionStorage.clear()
    const values = new Map()
    persistedStorage = {
      getItem: (key) => values.get(key) || null,
      setItem: (key, value) => values.set(key, String(value)),
      clear: () => values.clear()
    }
    vi.stubGlobal("localStorage", persistedStorage)
    vi.stubGlobal("requestAnimationFrame", (callback) => callback())
    document.body.innerHTML = `
      <input id="search-input" type="search">
      <div data-controller="player" data-player-radio-enabled-value="false" data-player-preferences-url-value="/player_preferences">
        <aside data-player-target="shell" hidden>
          <audio data-player-target="audio"></audio>
          <img data-player-target="artwork" src="/brand/sonzra-mark.svg" alt="">
          <strong data-player-target="title">Choose something to play</strong>
          <span data-player-target="artist">Your player will stay here</span>
          <button data-player-target="toggle"></button>
          <button data-player-target="radio"></button>
          <button data-player-target="shuffle"></button>
          <button data-player-target="trackSkip"></button>
          <button data-player-target="jumpBack" hidden></button>
          <button data-player-target="jumpForward" hidden></button>
          <button data-player-target="playbackRate" hidden>1.0x</button>
          <button data-player-target="muteButton" data-action="player#toggleMute">
            <span data-player-target="muteIcon"></span>
          </button>
          <input data-player-target="volume" type="range" min="0" max="1" step="0.01" value="0.8">
          <span data-player-target="miniProgress"></span>
        </aside>
        <dialog data-player-target="clearDialog"></dialog>
      </div>
    `
    vi.spyOn(HTMLMediaElement.prototype, "pause").mockImplementation(() => {})
    application = Application.start()
    application.register("player", PlayerController)
    await Promise.resolve()
    controller = application.getControllerForElementAndIdentifier(document.querySelector("[data-controller='player']"), "player")
  })

  afterEach(() => {
    controller?.disconnect()
    application?.stop()
    vi.useRealTimers()
    vi.unstubAllGlobals()
    vi.restoreAllMocks()
  })

  it("reveals the minimized player when a track is loaded", () => {
    controller.loadTrack({
      source: "/audio/track.mp3",
      title: "A track",
      artist: "An artist",
      artwork: "/artwork/track.jpg"
    })

    expect(document.querySelector("[data-player-target='shell']").hidden).toBe(false)
    expect(document.querySelector("[data-player-target='title']").textContent).toBe("A track")
    expect(document.querySelector("[data-player-target='artist']").textContent).toBe("An artist")
  })

  it("explains when a queue request returns no playable tracks", async () => {
    const feedback = document.createElement("p")
    feedback.dataset.playerTarget = "queueFeedback"
    document.querySelector("[data-controller='player']").appendChild(feedback)
    global.fetch = vi.fn(() => Promise.resolve({ ok: false }))

    await controller.replaceQueue({ params: { queueUrl: "/server_connections/1/playback_queues/album-1" } })

    expect(feedback.textContent).toBe("Sonzra couldn’t load playable tracks.")
    expect(feedback.hidden).toBe(false)
  })

  it("uses only downloaded tracks when the offline shell initializes the player", () => {
    controller.setOfflineQueue([
      { source: "/server_connections/1/audio/one", title: "One", artist: "Artist" },
      { source: "/server_connections/1/audio/two", title: "Two", artist: "Artist" }
    ], { source: "/server_connections/1/audio/two" })

    expect(controller.queue).toHaveLength(2)
    expect(controller.currentTrack.title).toBe("Two")
    expect(controller.radioEnabled).toBe(false)
    expect(document.querySelector("[data-player-target='shell']").hidden).toBe(false)
  })

  it("does not report playback while operating offline", () => {
    controller.offlineMode = true
    controller.currentTrack = { itemId: "track-1", reportingUrl: "/playback_reports" }
    global.fetch = vi.fn()

    controller.reportPlayback("progress")

    expect(global.fetch).not.toHaveBeenCalled()
  })

  it("enqueues playback events to the offline outbox while operating offline", async () => {
    controller.offlineMode = true
    controller.currentTrack = { itemId: "track-1", reportingUrl: "/server_connections/1/playback_reports" }
    controller.outbox = { enqueue: vi.fn(async () => 1) }
    global.fetch = vi.fn()

    controller.reportPlayback("progress")

    expect(global.fetch).not.toHaveBeenCalled()
    expect(controller.outbox.enqueue).toHaveBeenCalledWith(expect.objectContaining({
      event: "progress",
      itemId: "track-1",
      occurredAt: expect.any(String)
    }))
  })

  it("captures transient online fetch failures to the offline outbox", async () => {
    controller.offlineMode = false
    controller.currentTrack = { itemId: "track-1", reportingUrl: "/server_connections/1/playback_reports" }
    controller.outbox = { enqueue: vi.fn(async () => 1) }
    global.fetch = vi.fn().mockRejectedValue(new Error("Network failed"))

    controller.reportPlayback("started")
    await Promise.resolve()
    await Promise.resolve()

    expect(controller.outbox.enqueue).toHaveBeenCalledWith(expect.objectContaining({
      event: "started",
      itemId: "track-1",
      occurredAt: expect.any(String)
    }))
  })

  it("flushes queued events to the batch endpoint upon reconnection and displays a confirmation toast", async () => {
    const pendingEvents = [
      { id: 1, event: "started", itemId: "track-1", serverConnectionId: "1", positionTicks: 0, occurredAt: "2026-11-02T14:00:00Z" },
      { id: 2, event: "progress", itemId: "track-1", serverConnectionId: "1", positionTicks: 1000, occurredAt: "2026-11-02T14:01:00Z" }
    ]
    controller.outbox = {
      supported: () => true,
      pendingEvents: vi.fn(async () => pendingEvents),
      clearEvents: vi.fn(async () => {})
    }
    global.fetch = vi.fn(async () => ({ ok: true, status: 204 }))

    await controller.flushOutbox()

    expect(global.fetch).toHaveBeenCalledWith("/server_connections/1/playback_reports/batch", expect.objectContaining({
      method: "POST",
      body: JSON.stringify({
        events: [
          { event: "started", item_id: "track-1", position_ticks: 0, duration_ticks: 0, paused: undefined, resumable: false, occurred_at: "2026-11-02T14:00:00Z" },
          { event: "progress", item_id: "track-1", position_ticks: 1000, duration_ticks: 0, paused: undefined, resumable: false, occurred_at: "2026-11-02T14:01:00Z" }
        ]
      })
    }))
    expect(controller.outbox.clearEvents).toHaveBeenCalledWith([ 1, 2 ])

    const toast = document.querySelector(".flash.flash--notice")
    expect(toast).not.toBeNull()
    expect(toast.textContent).toContain("Synced 2 offline plays")
  })

  it("schedules exponential retry without clearing the queue when batch reporting fails", async () => {
    vi.useFakeTimers()
    const pendingEvents = [
      { id: 1, event: "started", itemId: "track-1", serverConnectionId: "1", positionTicks: 0, occurredAt: "2026-11-02T14:00:00Z" }
    ]
    controller.outbox = {
      supported: () => true,
      pendingEvents: vi.fn(async () => pendingEvents),
      clearEvents: vi.fn(async () => {})
    }
    global.fetch = vi.fn().mockRejectedValue(new Error("Server offline"))

    await controller.flushOutbox()

    expect(controller.outbox.clearEvents).not.toHaveBeenCalled()
    expect(controller.syncRetryAttempts).toBe(1)
    expect(controller.syncRetryTimeout).not.toBeNull()
  })

  it("clears events for successful connections even if a subsequent connection fails", async () => {
    const pendingEvents = [
      { id: 1, event: "started", itemId: "track-1", serverConnectionId: "conn-1", positionTicks: 0, occurredAt: "2026-11-02T14:00:00Z" },
      { id: 2, event: "started", itemId: "track-2", serverConnectionId: "conn-2", positionTicks: 0, occurredAt: "2026-11-02T14:00:00Z" }
    ]
    controller.outbox = {
      supported: () => true,
      pendingEvents: vi.fn(async () => pendingEvents),
      clearEvents: vi.fn(async () => {})
    }
    global.fetch = vi.fn()
      .mockResolvedValueOnce({ ok: true, status: 204 })
      .mockRejectedValueOnce(new Error("Conn 2 unreachable"))

    await controller.flushOutbox()

    expect(controller.outbox.clearEvents).toHaveBeenCalledWith([ 1 ])
    expect(controller.outbox.clearEvents).not.toHaveBeenCalledWith([ 2 ])
    expect(controller.syncRetryAttempts).toBe(1)
  })

  it("enables radio for a recommendation session queue", async () => {
    controller.tracksFor = vi.fn(async () => [ { source: "/audio/track-1", title: "Mix track" } ])
    controller.setRadioEnabled = vi.fn()

    await controller.replaceQueue({ params: { queueUrl: "/recommendation_collections/1", radioEnabled: true } })

    expect(controller.setRadioEnabled).toHaveBeenCalledWith(true)
  })

  it("shows radio as active after a mix starts", () => {
    controller.currentTrack = { radioEligible: true }

    controller.setRadioEnabled(true)

    const radio = document.querySelector("[data-player-target='radio']")
    expect(radio.classList.contains("is-active")).toBe(true)
    expect(radio.getAttribute("aria-label")).toBe("Radio on")
  })

  it("keeps the mobile queue radio control visible when radio is unavailable", () => {
    const radio = document.querySelector("[data-player-target='radio']")
    radio.classList.add("listen-queue__radio-control")
    controller.currentTrack = { radioEligible: false }

    controller.updateRadioControls()

    expect(radio.hidden).toBe(false)
    expect(radio.disabled).toBe(true)
    expect(radio.getAttribute("aria-label")).toBe("Radio unavailable for this track")
  })

  it("enables radio for restored playable tracks with a fallback radio endpoint", () => {
    const track = controller.normalizeTrack({
      source: "/server_connections/1/audio/track-1.mp3",
      itemId: "track-1",
      title: "A track",
      artist: "An artist"
    })

    expect(track.radioEligible).toBe(true)
    expect(track.radioUrl).toBe("/server_connections/1/radio_tracks/track-1")
  })

  it("enables and retains radio state for the current legacy queue track", async () => {
    const radio = document.querySelector("[data-player-target='radio']")
    controller.currentTrack = {
      source: "/server_connections/1/audio/track-1.mp3",
      item_id: "track-1",
      title: "A track",
      artist: "An artist"
    }
    global.fetch = vi.fn(() => Promise.resolve({ ok: true, json: () => Promise.resolve({ items: [] }) }))

    controller.updateRadioControls()
    await controller.toggleRadio()

    expect(radio.disabled).toBe(false)
    expect(radio.classList.contains("is-active")).toBe(true)
    expect(radio.getAttribute("aria-label")).toBe("Radio on")
    expect(controller.currentTrack.radioUrl).toBe("/server_connections/1/radio_tracks/track-1")
  })

  it("keeps the minimized progress indicator in sync with playback", () => {
    controller.updateProgress(30, 120)

    expect(document.querySelector("[data-player-target='miniProgress']").style.width).toBe("25%")
  })

  it("persists a volume change from the redesign player", () => {
    document.querySelector("[data-controller='player']").insertAdjacentHTML("beforeend", '<input data-player-target="volume" value="0.8">')
    const volume = document.querySelector("[data-player-target='volume']")
    volume.value = "0.35"

    controller.setVolume({ currentTarget: volume })

    expect(controller.audioTarget.volume).toBeCloseTo(0.35)
    expect(sessionStorage.getItem("sonzra:volume")).toBe("0.35")
    expect(volume.style.getPropertyValue("--volume-progress")).toBe("35%")
  })

  it("keeps the persistent player state in sync with playback", () => {
    controller.startVisualizer = vi.fn()
    controller.stopVisualizer = vi.fn()
    Object.defineProperty(controller.audioTarget, "paused", { configurable: true, value: false })

    controller.handlePlay()

    expect(document.querySelector("[data-player-target='shell']").classList).toContain("is-playing")
    expect(controller.startVisualizer).toHaveBeenCalled()

    Object.defineProperty(controller.audioTarget, "paused", { configurable: true, value: true })
    controller.handlePause()

    expect(document.querySelector("[data-player-target='shell']").classList).not.toContain("is-playing")
    expect(controller.stopVisualizer).toHaveBeenCalled()
  })

  it("keeps the queue mounted until its redesign transition finishes", () => {
    vi.useFakeTimers()
    document.querySelector("[data-controller='player']").insertAdjacentHTML("beforeend", '<section data-player-target="queuePanel"></section>')
    const queue = document.querySelector("[data-player-target='queuePanel']")
    queue.hidden = false

    controller.closeQueue()

    expect(queue.classList).toContain("is-closing")
    vi.advanceTimersByTime(319)
    expect(queue.hidden).toBe(false)
    vi.advanceTimersByTime(1)
    expect(queue.hidden).toBe(true)
  })

  it("loads and renders stored plain lyrics when the Lyrics view opens", async () => {
    addLyricsTargets()
    controller.currentTrack = { itemId: "track-1", source: "/server_connections/1/audio/track-1", title: "A track" }
    global.fetch = vi.fn(() => Promise.resolve({
      ok: true,
      json: () => Promise.resolve({ available: true, synchronized: false, lines: [ { text: "First line", start: null }, { text: "Second line", start: null } ] })
    }))

    await controller.showLyricsTab()

    expect(global.fetch).toHaveBeenCalledWith("/server_connections/1/lyrics/track-1", expect.any(Object))
    expect(document.querySelector("[data-player-target='lyricsView']").hidden).toBe(false)
    expect(document.querySelector("[data-player-target='lyricsList']").textContent).toContain("First line")
  })

  it("highlights and seeks synchronized lyric lines", () => {
    addLyricsTargets()
    controller.currentLyrics = { available: true, synchronized: true, lines: [ { text: "First", start: 10 }, { text: "Second", start: 20 } ] }
    controller.lyricsFollowing = false
    controller.renderLyrics(controller.currentLyrics)
    controller.audioTarget.currentTime = 21

    controller.updateActiveLyric()
    controller.seekLyricsLine(0)

    expect(document.querySelectorAll("[data-player-target='lyricsList'] li")[1].classList).toContain("is-current-lyric")
    expect(controller.audioTarget.currentTime).toBe(10)
  })

  it("keeps multiline lyric text together under one synchronized highlight", () => {
    addLyricsTargets()
    controller.currentLyrics = { available: true, synchronized: true, lines: [ { text: "First line\nSecond line", start: 10 } ] }
    controller.audioTarget.currentTime = 11

    controller.renderLyrics(controller.currentLyrics)

    const group = document.querySelector("[data-player-target='lyricsList'] li")
    expect(group.classList).toContain("listen-queue__lyric-group")
    expect(group.classList).toContain("is-current-lyric")
    expect(group.querySelectorAll(".listen-queue__lyric-line")).toHaveLength(1)
    expect(group.textContent).toBe("First line Second line")
  })

  it("shows an unavailable message when the server has no usable lyrics", () => {
    addLyricsTargets()

    controller.renderLyrics({ available: false, synchronized: false, lines: [] })

    expect(document.querySelector("[data-player-target='lyricsStatus']").textContent).toBe("Lyrics aren’t available for this track.")
  })

  it("reloads lyrics automatically when the next track loads while lyrics panel is open", async () => {
    addLyricsTargets()
    controller.activeExpandedView = "lyrics"
    controller.loadLyrics = vi.fn()

    controller.loadTrack({ source: "/server_connections/1/audio/track-2", title: "Next", artist: "Artist", artwork: "" })

    expect(controller.loadLyrics).toHaveBeenCalled()
  })

  it("does not reload lyrics automatically when the queue tab is active", () => {
    addLyricsTargets()
    controller.activeExpandedView = "queue"
    controller.loadLyrics = vi.fn()

    controller.loadTrack({ source: "/server_connections/1/audio/track-2", title: "Next", artist: "Artist", artwork: "" })

    expect(controller.loadLyrics).not.toHaveBeenCalled()
  })

  it("does not reload lyrics automatically before any tab has been selected", () => {
    addLyricsTargets()
    // activeExpandedView is undefined at controller startup
    controller.loadLyrics = vi.fn()

    controller.loadTrack({ source: "/server_connections/1/audio/track-2", title: "Next", artist: "Artist", artwork: "" })

    expect(controller.loadLyrics).not.toHaveBeenCalled()
  })

  it("sets activeExpandedView to lyrics when the lyrics tab is opened", async () => {
    addLyricsTargets()
    controller.currentTrack = { itemId: "track-1", source: "/server_connections/1/audio/track-1", title: "A track" }
    global.fetch = vi.fn(() => Promise.resolve({ ok: true, json: () => Promise.resolve({ available: true, synchronized: false, lines: [] }) }))

    await controller.showLyricsTab()

    expect(controller.activeExpandedView).toBe("lyrics")
  })

  it("sets activeExpandedView to queue when the queue tab is opened", async () => {
    addLyricsTargets()
    controller.activeExpandedView = "lyrics"

    controller.showQueueTab()

    expect(controller.activeExpandedView).toBe("queue")
  })

  it("does not interrupt lyric following for its own automatic scroll", () => {
    addLyricsTargets()
    controller.currentLyrics = { available: true, synchronized: true, lines: [ { text: "A line", start: 10 } ] }
    controller.lyricsFollowing = true
    controller.followingLyricScroll = true

    controller.pauseLyricsFollow()

    expect(controller.lyricsFollowing).toBe(true)
    expect(document.querySelector("[data-player-target='lyricsFollow']").hidden).toBe(true)
  })

  it("shows the follow action after manually scrolling synchronized lyrics", () => {
    addLyricsTargets()
    controller.currentLyrics = { available: true, synchronized: true, lines: [ { text: "A line", start: 10 } ] }
    controller.lyricsFollowing = true
    controller.followingLyricScroll = false

    controller.pauseLyricsFollow()

    expect(controller.lyricsFollowing).toBe(false)
    expect(document.querySelector("[data-player-target='lyricsFollow']").hidden).toBe(false)
  })

  it("persists the current queue and playback position for a restored player", () => {
    controller.queue = [ { source: "/audio/track.mp3", title: "A track", artist: "An artist" } ]
    controller.currentIndex = 0
    controller.audioTarget.currentTime = 42

    controller.persistQueue({ force: true })

    expect(JSON.parse(persistedStorage.getItem("sonzra:player-state"))).toMatchObject({
      version: 1,
      queue: controller.queue,
      currentIndex: 0,
      position: 42,
      queueOpen: false,
      repeatMode: "off"
    })
  })

  it("cycles repeat mode and restarts the current track in repeat-one mode", () => {
    controller.queue = [ { source: "/audio/track.mp3", title: "A track", artist: "An artist" } ]
    controller.currentIndex = 0
    controller.repeatMode = "off"
    controller.audioTarget.play = vi.fn(() => Promise.resolve())

    controller.toggleRepeat()
    expect(controller.repeatMode).toBe("all")
    controller.toggleRepeat()
    expect(controller.repeatMode).toBe("one")
    controller.playNext()

    expect(controller.audioTarget.currentTime).toBe(0)
    expect(controller.audioTarget.play).toHaveBeenCalled()
  })

  it("renders a favourite control for each queued track", async () => {
    document.querySelector("[data-controller='player']").insertAdjacentHTML("beforeend", '<ol data-player-target="queueList"></ol>')
    controller.queue = [ { source: "/server_connections/1/audio/track.mp3", title: "A track", artist: "An artist" } ]
    controller.currentIndex = 0
    await Promise.resolve()

    controller.renderQueue()

    expect(document.querySelector(".listen-queue__item-favorite").getAttribute("aria-label")).toBe("Add A track to favourites")
  })

  it("renders an add-to-playlist control for each queued track", async () => {
    document.querySelector("[data-controller='player']").insertAdjacentHTML("beforeend", '<ol data-player-target="queueList"></ol>')
    controller.queue = [ { source: "/server_connections/1/audio/track-1", itemId: "track-1", title: "A track", artist: "An artist" } ]
    controller.currentIndex = 0
    await Promise.resolve()

    controller.renderQueue()

    expect(document.querySelector(".listen-queue__item-playlist").getAttribute("aria-label")).toBe("Add A track to playlist")
    expect(document.querySelector(".listen-queue__item-menu")).not.toBeNull()
    expect(document.querySelector(".listen-queue__item-menu-toggle svg")).not.toBeNull()
    expect(document.querySelectorAll(".listen-queue__item-action")).toHaveLength(1)
  })

  it("shows the queue scroll hint only while tracks remain below the viewport", () => {
    document.querySelector("[data-controller='player']").insertAdjacentHTML("beforeend", '<div data-player-target="queueView"><ol data-player-target="queueList"></ol></div>')
    const queueView = document.querySelector("[data-player-target='queueView']")
    const queueList = document.querySelector("[data-player-target='queueList']")
    Object.defineProperties(queueList, {
      clientHeight: { configurable: true, value: 100 },
      scrollHeight: { configurable: true, value: 180 },
      scrollTop: { configurable: true, value: 0, writable: true }
    })

    controller.updateQueueScrollHint()
    expect(queueView.classList).toContain("has-scroll-hint")

    queueList.scrollTop = 80
    controller.updateQueueScrollHint()
    expect(queueView.classList).not.toContain("has-scroll-hint")
  })

  it("positions an open queue menu outside the scrollable queue list", async () => {
    document.querySelector("[data-controller='player']").insertAdjacentHTML("beforeend", '<section data-player-target="queuePanel"><ol data-player-target="queueList"></ol></section>')
    controller.queue = [ { source: "/server_connections/1/audio/track-1.mp3", title: "A track", artist: "An artist" } ]
    controller.currentIndex = 0
    await Promise.resolve()
    controller.renderQueue()

    const toggle = document.querySelector(".listen-queue__item-menu-toggle")
    const menu = document.querySelector(".listen-queue__item-menu-actions")
    toggle.getBoundingClientRect = () => ({ top: 20, bottom: 58, right: 320 })
    menu.getBoundingClientRect = () => ({ width: 194, height: 160 })
    toggle.click()

    expect(menu.style.getPropertyValue("--queue-menu-left")).toBe("126px")
    expect(menu.style.getPropertyValue("--queue-menu-top")).toBe("64px")
    expect(menu.parentElement).toBe(document.querySelector("[data-player-target='queuePanel']"))
  })

  it("dismisses an open queue menu when clicking outside it", async () => {
    document.querySelector("[data-controller='player']").insertAdjacentHTML("beforeend", '<section data-player-target="queuePanel"><ol data-player-target="queueList"></ol></section>')
    controller.queue = [ { source: "/server_connections/1/audio/track-1.mp3", title: "A track", artist: "An artist" } ]
    controller.currentIndex = 0
    await Promise.resolve()
    controller.renderQueue()

    document.querySelector(".listen-queue__item-menu-toggle").click()
    document.body.click()

    expect(document.querySelector(".listen-queue__item-menu-actions")).toBeNull()
  })

  it("updates the queue favourite icon when favouriting from the player", async () => {
    document.querySelector("[data-controller='player']").insertAdjacentHTML("beforeend", '<ol data-player-target="queueList"></ol>')
    controller.queue = [ { source: "/server_connections/1/audio/track.mp3", title: "A track", artist: "An artist", favorite: false } ]
    controller.currentIndex = 0
    controller.currentTrack = controller.queue[0]
    global.fetch = vi.fn(() => Promise.resolve({ ok: true }))
    await Promise.resolve()

    controller.renderQueue()
    await controller.toggleFavorite()

    expect(document.querySelector(".listen-queue__item-favorite").classList).toContain("is-active")
    expect(document.querySelector(".listen-queue__item-favorite").getAttribute("aria-label")).toBe("Remove A track from favourites")
  })

  it("marks a favourite immediately while its request is still pending", () => {
    document.querySelector("[data-controller='player']").insertAdjacentHTML("beforeend", '<button data-player-target="favorite"></button>')
    controller.queue = [ { source: "/server_connections/1/audio/track.mp3", title: "A track", artist: "An artist", favorite: false } ]
    controller.currentIndex = 0
    controller.currentTrack = controller.queue[0]
    global.fetch = vi.fn(() => new Promise(() => {}))

    controller.toggleFavorite()

    expect(controller.favoriteState(controller.currentTrack)).toBe(true)
    expect(document.querySelector("[data-player-target='favorite']").classList).toContain("is-active")
    controller.persistQueue({ force: true })
    expect(JSON.parse(localStorage.getItem("sonzra:player-state")).queue[0].favorite).toBe(false)
  })

  it("shows pause for the playing queue item and toggles it without restarting", async () => {
    document.querySelector("[data-controller='player']").insertAdjacentHTML("beforeend", '<ol data-player-target="queueList"></ol>')
    controller.queue = [ { source: "/server_connections/1/audio/track.mp3", title: "A track", artist: "An artist" } ]
    controller.currentIndex = 0
    controller.audioTarget.src = "/server_connections/1/audio/track.mp3"
    Object.defineProperty(controller.audioTarget, "paused", { configurable: true, value: false })
    await Promise.resolve()

    controller.renderQueue()

    expect(document.querySelector(".listen-queue__item-play").getAttribute("aria-label")).toBe("Pause A track")
  })

  it("removes a non-current queued track", async () => {
    document.querySelector("[data-controller='player']").insertAdjacentHTML("beforeend", '<ol data-player-target="queueList"></ol>')
    controller.queue = [
      { source: "/server_connections/1/audio/track-1.mp3", title: "First", artist: "An artist" },
      { source: "/server_connections/1/audio/track-2.mp3", title: "Second", artist: "An artist" }
    ]
    controller.currentIndex = 0
    await Promise.resolve()

    controller.removeQueuedTrack(1)

    expect(controller.queue).toHaveLength(1)
    expect(controller.queue[0].title).toBe("First")
    expect(controller.currentIndex).toBe(0)
  })

  it("removes the current track and advances to the next one", async () => {
    document.querySelector("[data-controller='player']").insertAdjacentHTML("beforeend", '<ol data-player-target="queueList"></ol>')
    controller.queue = [
      { source: "/server_connections/1/audio/track-1.mp3", title: "First", artist: "An artist" },
      { source: "/server_connections/1/audio/track-2.mp3", title: "Second", artist: "An artist" }
    ]
    controller.currentIndex = 0
    controller.playCurrent = vi.fn()
    await Promise.resolve()

    controller.removeQueuedTrack(0)

    expect(controller.queue).toHaveLength(1)
    expect(controller.queue[0].title).toBe("Second")
    expect(controller.currentIndex).toBe(0)
    expect(controller.playCurrent).toHaveBeenCalled()
  })

  it("restores the saved track at its paused playback position", () => {
    persistedStorage.setItem("sonzra:player-state", JSON.stringify({
      version: 1,
      queue: [ { source: "/audio/track.mp3", title: "A track", artist: "An artist" } ],
      currentIndex: 0,
      position: 42,
      queueOpen: false
    }))

    controller.restoreQueue()

    expect(controller.currentTrack.title).toBe("A track")
    expect(controller.pendingStartPosition).toBe(42)
    expect(controller.audioTarget.paused).toBe(true)
  })

  it("reports a paused track as playback progress instead of stopped", () => {
    controller.currentTrack = { itemId: "track-1", reportingUrl: "/playback_reports" }
    controller.hasReportedStart = true
    controller.reportPlayback = vi.fn()

    controller.handlePause()

    expect(controller.reportPlayback).toHaveBeenCalledWith("progress")
    expect(controller.reportPlayback).not.toHaveBeenCalledWith("stopped")
  })

  it("keeps the playback session alive when the page is hidden", () => {
    controller.reportPlayback = vi.fn()
    controller.persistQueue = vi.fn()

    controller.handlePageHide()

    expect(controller.persistQueue).toHaveBeenCalledWith({ force: true })
    expect(controller.reportPlayback).toHaveBeenCalledWith("progress", { keepalive: true })
  })

  it("retries a failed stream from its last playback position", () => {
    vi.useFakeTimers()
    controller.currentTrack = { source: "/audio/track.mp3", title: "A track", artist: "An artist" }
    controller.playbackRequested = true
    controller.audioTarget.currentTime = 42
    controller.audioTarget.load = vi.fn()
    controller.audioTarget.play = vi.fn(() => Promise.resolve())

    controller.handlePlaybackError()
    vi.runAllTimers()

    expect(controller.audioTarget.load).toHaveBeenCalled()
    expect(controller.audioTarget.play).toHaveBeenCalled()
    expect(controller.pendingStartPosition).toBe(42)
    expect(controller.playbackRecoveryAttempts).toBe(1)
  })

  it("updates the page title and active album track control", () => {
    document.body.insertAdjacentHTML("beforeend", `
      <ol class="track-list"><li><button class="listen-card__play" data-player-item-id-param="track-1" data-player-title-param="A track" data-action="player#replaceQueue">Play</button></li></ol>
    `)
    controller.currentTrack = { itemId: "track-1", title: "A track", artist: "An artist" }

    controller.syncBrowserMedia()
    controller.syncPageTrackControls()

    const button = document.querySelector(".listen-card__play")
    expect(document.title).toBe("A track · An artist | Sonzra")
    expect(button.dataset.action).toBe("player#toggle")
    expect(button.getAttribute("aria-label")).toBe("Play A track")
    expect(button.closest("li").classList).toContain("is-playing")
  })

  it("extends the queue from radio recommendations when the queue is about to end", async () => {
    controller.queue = [
      { source: "/server_connections/1/audio/track-1.mp3", title: "Seed", artist: "Artist", itemId: "track-1", radioUrl: "/server_connections/1/radio_tracks/track-1", radioEligible: true }
    ]
    controller.currentIndex = 0
    controller.currentTrack = controller.queue[0]
    controller.radioEnabled = true
    global.fetch = vi.fn(() => Promise.resolve({
      ok: true,
      json: () => Promise.resolve({
        items: [
          { item_id: "track-1", source: "/server_connections/1/audio/track-1.mp3", title: "Seed", artist: "Artist" },
          { item_id: "track-2", source: "/server_connections/1/audio/track-2.mp3", title: "Second", artist: "Artist", radio_url: "/server_connections/1/radio_tracks/track-2", radio_eligible: true }
        ]
      })
    }))

    await controller.maybeExtendRadioQueue({ force: true })

    expect(global.fetch).toHaveBeenCalledWith("/server_connections/1/radio_tracks/track-1?limit=8", expect.any(Object))
    expect(controller.queue).toHaveLength(2)
    expect(controller.queue[1].itemId).toBe("track-2")
  })

  it("toggles radio state and syncs the preference", async () => {
    controller.currentTrack = { itemId: "track-1", title: "Seed", artist: "Artist", radioEligible: true, radioUrl: "/server_connections/1/radio_tracks/track-1" }
    document.querySelector("[data-controller='player']").insertAdjacentHTML("beforeend", '<p data-player-target="queueFeedback" hidden></p>')
    global.fetch = vi.fn(() => Promise.resolve({ ok: true, json: () => Promise.resolve({ items: [] }) }))

    await controller.toggleRadio()

    expect(controller.radioEnabled).toBe(true)
    expect(global.fetch).toHaveBeenCalledWith("/player_preferences", expect.objectContaining({ method: "PATCH" }))
    expect(document.querySelector("[data-player-target='radio']").getAttribute("aria-label")).toBe("Radio on")
    expect(document.querySelector("[data-player-target='queueFeedback']").hidden).toBe(true)
  })

  it("does not append more radio tracks when re-enabling with enough queue ahead", async () => {
    controller.queue = [
      { source: "/server_connections/1/audio/track-1.mp3", title: "Seed", artist: "Artist", itemId: "track-1", radioUrl: "/server_connections/1/radio_tracks/track-1", radioEligible: true },
      { source: "/server_connections/1/audio/track-2.mp3", title: "Second", artist: "Artist", itemId: "track-2" },
      { source: "/server_connections/1/audio/track-3.mp3", title: "Third", artist: "Artist", itemId: "track-3" },
      { source: "/server_connections/1/audio/track-4.mp3", title: "Fourth", artist: "Artist", itemId: "track-4" }
    ]
    controller.currentIndex = 0
    controller.currentTrack = controller.queue[0]
    controller.radioEnabled = false
    global.fetch = vi.fn(() => Promise.resolve({ ok: true, json: () => Promise.resolve({ items: [] }) }))

    await controller.toggleRadio()

    expect(controller.radioEnabled).toBe(true)
    expect(global.fetch).toHaveBeenCalledTimes(1)
    expect(controller.queue).toHaveLength(4)
  })

  it("turns radio off when replacing the queue with an album", async () => {
    controller.radioEnabled = true
    controller.updateRadioControls()
    controller.playCurrent = vi.fn()
    global.fetch = vi.fn(() => Promise.resolve({
      ok: true,
      json: () => Promise.resolve({
        items: [
          { item_id: "track-2", source: "/server_connections/1/audio/track-2.mp3", title: "Second", artist: "Artist", radio_url: "/server_connections/1/radio_tracks/track-2", radio_eligible: true }
        ]
      })
    }))

    await controller.replaceQueue({ params: { queueUrl: "/server_connections/1/playback_queues/album-1" } })

    expect(controller.radioEnabled).toBe(false)
    expect(global.fetch).toHaveBeenCalledWith("/player_preferences", expect.objectContaining({ method: "PATCH" }))
  })

  it("turns radio off when the queue is cleared", () => {
    controller.radioEnabled = true
    controller.queue = [ { source: "/server_connections/1/audio/track-1.mp3", title: "Seed", artist: "Artist", itemId: "track-1" } ]
    controller.currentIndex = 0
    controller.currentTrack = controller.queue[0]
    global.fetch = vi.fn(() => Promise.resolve({ ok: true, json: () => Promise.resolve({ items: [] }) }))

    controller.clearQueue()

    expect(controller.radioEnabled).toBe(false)
    expect(global.fetch).toHaveBeenCalledWith("/player_preferences", expect.objectContaining({ method: "PATCH" }))
  })

  it("clears the whole queue, stops playback, and hides the player", () => {
    controller.queue = [ { source: "/server_connections/1/audio/track-1.mp3", title: "Seed", artist: "Artist", itemId: "track-1" } ]
    controller.currentIndex = 0
    controller.currentTrack = controller.queue[0]
    controller.audioTarget.load = vi.fn()
    Object.defineProperty(controller.audioTarget, "src", { configurable: true, value: "/server_connections/1/audio/track-1.mp3", writable: true })

    controller.clearQueue()

    expect(controller.queue).toEqual([])
    expect(controller.currentTrack).toBeNull()
    expect(controller.audioTarget.pause).toHaveBeenCalled()
    expect(controller.audioTarget.load).toHaveBeenCalled()
    expect(document.querySelector("[data-player-target='shell']").hidden).toBe(true)
  })

  it("opens and closes the custom clear confirmation", () => {
    controller.clearDialogTarget.showModal = vi.fn(function () { this.setAttribute("open", "") })
    controller.clearDialogTarget.close = vi.fn(function () { this.removeAttribute("open") })

    controller.promptClearQueue()
    expect(controller.clearDialogTarget.showModal).toHaveBeenCalled()
    expect(controller.clearDialogTarget.hasAttribute("open")).toBe(true)

    controller.closeClearQueuePrompt()
    expect(controller.clearDialogTarget.close).toHaveBeenCalled()
    expect(controller.clearDialogTarget.hasAttribute("open")).toBe(false)
  })

  it("does not clear the queue until the confirmation is accepted", () => {
    controller.queue = [ { source: "/server_connections/1/audio/track-1.mp3", title: "Seed", artist: "Artist", itemId: "track-1" } ]
    controller.currentIndex = 0
    controller.currentTrack = controller.queue[0]

    controller.promptClearQueue()

    expect(controller.queue).toHaveLength(1)
    expect(controller.currentTrack.itemId).toBe("track-1")
  })

  it("clears the queue after confirming", () => {
    controller.queue = [ { source: "/server_connections/1/audio/track-1.mp3", title: "Seed", artist: "Artist", itemId: "track-1" } ]
    controller.currentIndex = 0
    controller.currentTrack = controller.queue[0]
    controller.audioTarget.load = vi.fn()
    controller.clearDialogTarget.close = vi.fn()

    controller.confirmClearQueue()

    expect(controller.clearDialogTarget.close).toHaveBeenCalled()
    expect(controller.queue).toEqual([])
    expect(controller.currentTrack).toBeNull()
  })

  it("computes lookahead buffer seconds accurately from audio target", () => {
    controller.audioTarget.currentTime = 10
    Object.defineProperty(controller.audioTarget, "buffered", {
      configurable: true,
      value: {
        length: 1,
        start: () => 0,
        end: () => 65
      }
    })

    expect(controller.lookaheadBufferSeconds()).toBe(55)
    expect(controller.isLookaheadBufferSafe(45)).toBe(true)
  })

  it("indicates lookahead buffer is not safe when buffer depth is low", () => {
    controller.audioTarget.currentTime = 50
    Object.defineProperty(controller.audioTarget, "buffered", {
      configurable: true,
      value: {
        length: 1,
        start: () => 0,
        end: () => 65
      }
    })

    expect(controller.lookaheadBufferSeconds()).toBe(15)
    expect(controller.isLookaheadBufferSafe(45)).toBe(false)
  })

  it("enters soft reconnecting state when audio is waiting or stalled", () => {
    controller.playbackRequested = true
    controller.audioTarget.dispatchEvent(new Event("waiting"))

    expect(controller.isReconnecting).toBe(true)
    expect(controller.toggleTarget.classList.contains("is-reconnecting")).toBe(true)
    expect(controller.toggleTarget.getAttribute("aria-busy")).toBe("true")

    controller.audioTarget.dispatchEvent(new Event("canplay"))
    expect(controller.isReconnecting).toBe(false)
    expect(controller.toggleTarget.classList.contains("is-reconnecting")).toBe(false)
    expect(controller.toggleTarget.hasAttribute("aria-busy")).toBe(false)
  })

  it("toggles and persists preloadOnWifiOnly player preference", async () => {
    vi.stubGlobal("fetch", vi.fn(async () => ({ ok: true })))
    const button = document.createElement("button")
    button.setAttribute("data-player-target", "wifiPreload")
    controller.element.appendChild(button)
    controller.connect()

    expect(controller.preloadOnWifiOnly).toBe(false)

    await controller.togglePreloadOnWifiOnly()
    expect(controller.preloadOnWifiOnly).toBe(true)
    expect(button.getAttribute("aria-pressed")).toBe("true")
    expect(global.fetch).toHaveBeenCalledWith("/player_preferences", expect.objectContaining({
      method: "PATCH",
      body: JSON.stringify({ preload_on_wifi_only: true })
    }))
  })

  it("prefetches track N+1 when active track lookahead buffer is safe (AE1)", async () => {
    const putSpy = vi.fn(async () => {})
    controller.ephemeralStreamStore = {
      has: vi.fn(async () => false),
      put: putSpy,
      touch: vi.fn()
    }
    vi.stubGlobal("fetch", vi.fn(async () => ({ ok: true, clone: vi.fn(() => ({ cloned: true })) })))

    controller.queue = [
      { source: "/audio/track-1.mp3", title: "Track 1" },
      { source: "/audio/track-2.mp3", title: "Track 2" }
    ]
    controller.currentIndex = 0
    controller.currentTrack = controller.queue[0]

    // Buffer < 45s: prefetch must NOT start
    controller.audioTarget.currentTime = 10
    Object.defineProperty(controller.audioTarget, "buffered", {
      configurable: true,
      value: { length: 1, start: () => 0, end: () => 20 }
    })
    await controller.maybePreloadNextTrack()
    expect(global.fetch).not.toHaveBeenCalledWith("/audio/track-2.mp3", expect.anything())

    // Buffer >= 45s: prefetch must start
    Object.defineProperty(controller.audioTarget, "buffered", {
      configurable: true,
      value: { length: 1, start: () => 0, end: () => 65 }
    })
    await controller.maybePreloadNextTrack()
    expect(global.fetch).toHaveBeenCalledWith("/audio/track-2.mp3", expect.objectContaining({ credentials: "same-origin" }))
    expect(putSpy).toHaveBeenCalledWith("/audio/track-2.mp3", expect.anything())
  })

  it("aborts in-flight prefetch when skipping or clearing the queue (AE2)", async () => {
    controller.ephemeralStreamStore = {
      has: vi.fn(async () => false),
      put: vi.fn(async () => {})
    }
    controller.queue = [
      { source: "/audio/track-1.mp3", title: "Track 1" },
      { source: "/audio/track-2.mp3", title: "Track 2" }
    ]
    controller.currentIndex = 0
    controller.currentTrack = controller.queue[0]
    controller.audioTarget.currentTime = 10
    Object.defineProperty(controller.audioTarget, "buffered", {
      configurable: true,
      value: { length: 1, start: () => 0, end: () => 65 }
    })

    let abortSignal
    vi.stubGlobal("fetch", vi.fn((_url, options) => {
      abortSignal = options?.signal
      return new Promise((resolve, reject) => {
        if (options?.signal?.aborted) {
          reject(new DOMException("The user aborted a request.", "AbortError"))
        } else {
          options?.signal?.addEventListener("abort", () => {
            reject(new DOMException("The user aborted a request.", "AbortError"))
          })
        }
      })
    }))

    const preloadPromise = controller.maybePreloadNextTrack()
    await Promise.resolve()
    expect(abortSignal).toBeDefined()
    expect(abortSignal.aborted).toBe(false)

    controller.cancelPreload()
    expect(abortSignal.aborted).toBe(true)
    await preloadPromise
  })

  it("suppresses prefetching when preloadOnWifiOnly is enabled on cellular network (AE3)", async () => {
    controller.preloadOnWifiOnly = true
    vi.stubGlobal("navigator", {
      connection: { type: "cellular", saveData: false }
    })
    vi.stubGlobal("fetch", vi.fn(async () => ({ ok: true })))

    controller.queue = [
      { source: "/audio/track-1.mp3", title: "Track 1" },
      { source: "/audio/track-2.mp3", title: "Track 2" }
    ]
    controller.currentIndex = 0
    controller.currentTrack = controller.queue[0]
    controller.audioTarget.currentTime = 10
    Object.defineProperty(controller.audioTarget, "buffered", {
      configurable: true,
      value: { length: 1, start: () => 0, end: () => 65 }
    })

    await controller.maybePreloadNextTrack()
    expect(global.fetch).not.toHaveBeenCalled()
  })

  it("toggles shuffle mode and updates target aria-pressed and classes (R1)", () => {
    document.querySelector("[data-player-target='shell']").insertAdjacentHTML("beforeend", `
      <button data-player-target="shuffle" aria-label="Shuffle off" aria-pressed="false"></button>
    `)
    expect(controller.shuffleMode).toBe(false)

    controller.toggleShuffle()
    expect(controller.shuffleMode).toBe(true)
    const button = document.querySelector("[data-player-target='shuffle']")
    expect(button.classList.contains("is-active")).toBe(true)
    expect(button.getAttribute("aria-pressed")).toBe("true")
    expect(button.getAttribute("aria-label")).toBe("Shuffle on")

    controller.toggleShuffle()
    expect(controller.shuffleMode).toBe(false)
    expect(button.classList.contains("is-active")).toBe(false)
    expect(button.getAttribute("aria-pressed")).toBe("false")
    expect(button.getAttribute("aria-label")).toBe("Shuffle off")
  })

  it("traverses remaining queue in randomized order when shuffle is enabled (R2, F1)", () => {
    controller.queue = [
      { source: "/audio/track-1.mp3", title: "Track 1" },
      { source: "/audio/track-2.mp3", title: "Track 2" },
      { source: "/audio/track-3.mp3", title: "Track 3" },
      { source: "/audio/track-4.mp3", title: "Track 4" }
    ]
    controller.currentIndex = 0
    controller.currentTrack = controller.queue[0]
    vi.spyOn(controller, "playQueueIndex").mockImplementation((index) => {
      controller.currentIndex = index
      controller.currentTrack = controller.queue[index]
    })

    // Stub Math.random to return deterministically
    vi.spyOn(Math, "random").mockReturnValue(0.99)
    controller.shuffleMode = true
    controller.generateShuffledOrder()

    controller.playNext()
    expect(controller.playQueueIndex).toHaveBeenCalled()
    const firstPlayed = controller.playQueueIndex.mock.calls[0][0]
    expect(firstPlayed).not.toBe(0)
    expect(firstPlayed).toBeGreaterThanOrEqual(1)
    expect(firstPlayed).toBeLessThanOrEqual(3)
  })

  it("restores natural queue order when shuffle is toggled off (R3, AE3)", () => {
    controller.queue = [
      { source: "/audio/track-1.mp3", title: "Track 1" },
      { source: "/audio/track-2.mp3", title: "Track 2" },
      { source: "/audio/track-3.mp3", title: "Track 3" },
      { source: "/audio/track-4.mp3", title: "Track 4" }
    ]
    controller.currentIndex = 1 // Track 2 is active
    controller.currentTrack = controller.queue[1]
    controller.shuffleMode = true
    controller.shuffledIndices = [3, 0] // random order pending

    vi.spyOn(controller, "playQueueIndex").mockImplementation((index) => {
      controller.currentIndex = index
    })

    // Toggle shuffle off
    controller.toggleShuffle()
    expect(controller.shuffleMode).toBe(false)
    expect(controller.shuffledIndices).toEqual([])

    controller.playNext()
    // In natural order, next after index 1 is index 2 (Track 3)
    expect(controller.playQueueIndex).toHaveBeenCalledWith(2)
  })

  it("starts playback in shuffled mode when queue is replaced with shuffle param (R4)", async () => {
    vi.spyOn(controller, "tracksFor").mockResolvedValue([
      { source: "/audio/track-1.mp3", title: "Track 1" },
      { source: "/audio/track-2.mp3", title: "Track 2" },
      { source: "/audio/track-3.mp3", title: "Track 3" }
    ])
    vi.spyOn(controller, "playCurrent").mockImplementation(() => {})

    await controller.replaceQueue({
      params: { shuffle: "true", queueUrl: "/queue/album-1" }
    })

    expect(controller.shuffleMode).toBe(true)
    expect(controller.queue.length).toBe(3)
    expect(controller.shuffledIndices.length).toBe(2)
  })

  it("adapts transport controls for longform spoken audio and restores music controls (R5, R6, F2)", () => {
    const shuffleBtn = document.querySelector("[data-player-target='shuffle']")
    const trackSkipBtn = document.querySelector("[data-player-target='trackSkip']")
    const jumpBackBtn = document.querySelector("[data-player-target='jumpBack']")
    const jumpForwardBtn = document.querySelector("[data-player-target='jumpForward']")
    const rateBtn = document.querySelector("[data-player-target='playbackRate']")

    // 1. Load an audiobook track
    controller.loadTrack({
      source: "/audio/chapter-1.mp3",
      title: "Chapter 1",
      artist: "Author",
      kind: "audiobook"
    })

    expect(shuffleBtn.hidden).toBe(true)
    expect(trackSkipBtn.hidden).toBe(true)
    expect(jumpBackBtn.hidden).toBe(false)
    expect(jumpForwardBtn.hidden).toBe(false)
    expect(rateBtn.hidden).toBe(false)

    // 2. Load a music track
    controller.loadTrack({
      source: "/audio/song.mp3",
      title: "A Song",
      artist: "Musician",
      kind: "music"
    })

    expect(shuffleBtn.hidden).toBe(false)
    expect(trackSkipBtn.hidden).toBe(false)
    expect(jumpBackBtn.hidden).toBe(true)
    expect(jumpForwardBtn.hidden).toBe(true)
    expect(rateBtn.hidden).toBe(true)
    expect(controller.audioTarget.playbackRate).toBe(1.0)
  })

  it("jumps backward 15 seconds clamped to 0 (R6)", () => {
    controller.loadTrack({ source: "/audio/book.mp3", title: "Book", kind: "audiobook" })
    controller.audioTarget.currentTime = 20
    controller.skipBackward(15)
    expect(controller.audioTarget.currentTime).toBe(5)

    controller.skipBackward(15)
    expect(controller.audioTarget.currentTime).toBe(0)
  })

  it("jumps forward 30 seconds clamped to duration (R6)", () => {
    controller.loadTrack({ source: "/audio/book.mp3", title: "Book", kind: "audiobook" })
    Object.defineProperty(controller.audioTarget, "duration", { value: 60, configurable: true })
    controller.audioTarget.currentTime = 10

    controller.skipForward(30)
    expect(controller.audioTarget.currentTime).toBe(40)

    controller.skipForward(30)
    expect(controller.audioTarget.currentTime).toBe(60)
  })

  it("cycles playback rate with preservesPitch and persists to localStorage (R5)", () => {
    controller.loadTrack({ source: "/audio/book.mp3", title: "Book", kind: "audiobook" })
    const rateBtn = document.querySelector("[data-player-target='playbackRate']")

    // Default rate is 1.0x
    expect(controller.audioTarget.playbackRate).toBe(1.0)
    expect(rateBtn.textContent).toBe("1x")

    // Cycle 1.0 -> 1.2
    controller.cyclePlaybackRate()
    expect(controller.audioTarget.playbackRate).toBe(1.2)
    expect(controller.audioTarget.preservesPitch).toBe(true)
    expect(rateBtn.textContent).toBe("1.2x")
    expect(localStorage.getItem("sonzra:playbackRate")).toBe("1.2")

    // Cycle 1.2 -> 1.5
    controller.cyclePlaybackRate()
    expect(controller.audioTarget.playbackRate).toBe(1.5)

    // Cycle 1.5 -> 2.0
    controller.cyclePlaybackRate()
    expect(controller.audioTarget.playbackRate).toBe(2)

    // Cycle 2.0 -> 0.8
    controller.cyclePlaybackRate()
    expect(controller.audioTarget.playbackRate).toBe(0.8)

    // Cycle 0.8 -> 1.0
    controller.cyclePlaybackRate()
    expect(controller.audioTarget.playbackRate).toBe(1)
  })

  it("registers seekbackward and seekforward mediaSession action handlers (R6)", () => {
    const handlers = {}
    const mockMediaSession = {
      metadata: null,
      playbackState: "none",
      setActionHandler: vi.fn((action, handler) => { handlers[action] = handler }),
      setPositionState: vi.fn()
    }
    vi.stubGlobal("navigator", { mediaSession: mockMediaSession })
    vi.stubGlobal("MediaMetadata", class { constructor(meta) { Object.assign(this, meta) } })

    controller.loadTrack({ source: "/audio/podcast.mp3", title: "Podcast", kind: "podcast" })
    controller.audioTarget.currentTime = 50
    Object.defineProperty(controller.audioTarget, "duration", { value: 100, configurable: true })

    expect(mockMediaSession.setActionHandler).toHaveBeenCalledWith("seekbackward", expect.any(Function))
    expect(mockMediaSession.setActionHandler).toHaveBeenCalledWith("seekforward", expect.any(Function))

    // Invoke backward handler
    handlers["seekbackward"]({ seekOffset: 15 })
    expect(controller.audioTarget.currentTime).toBe(35)

    // Invoke forward handler
    handlers["seekforward"]({ seekOffset: 30 })
    expect(controller.audioTarget.currentTime).toBe(65)
  })

  it("does not trigger play/pause or mute when typing Space or M inside an input (R7, R8, AE1)", () => {
    controller.loadTrack({ source: "/audio/track.mp3", title: "Track", artist: "Artist" })
    controller.audioTarget.volume = 0.8
    vi.spyOn(controller, "toggle")
    vi.spyOn(controller, "toggleMute")

    const searchInput = document.getElementById("search-input")
    searchInput.focus()

    // Dispatch Space from inside input
    const spaceEvent = new KeyboardEvent("keydown", { code: "Space", key: " ", bubbles: true, cancelable: true })
    searchInput.dispatchEvent(spaceEvent)
    expect(controller.toggle).not.toHaveBeenCalled()
    expect(spaceEvent.defaultPrevented).toBe(false)

    // Dispatch M from inside input
    const mEvent = new KeyboardEvent("keydown", { key: "m", bubbles: true, cancelable: true })
    searchInput.dispatchEvent(mEvent)
    expect(controller.toggleMute).not.toHaveBeenCalled()
    expect(mEvent.defaultPrevented).toBe(false)
  })

  it("toggles play/pause on Space key press when focused outside inputs (R7)", () => {
    controller.loadTrack({ source: "/audio/track.mp3", title: "Track", artist: "Artist" })
    vi.spyOn(controller, "toggle").mockImplementation(() => {})

    const spaceEvent = new KeyboardEvent("keydown", { code: "Space", key: " ", bubbles: true, cancelable: true })
    window.dispatchEvent(spaceEvent)

    expect(controller.toggle).toHaveBeenCalled()
    expect(spaceEvent.defaultPrevented).toBe(true)
  })

  it("seeks relative -5s and +5s on ArrowLeft and ArrowRight (R7)", () => {
    controller.loadTrack({ source: "/audio/track.mp3", title: "Track", artist: "Artist" })
    controller.audioTarget.currentTime = 10
    Object.defineProperty(controller.audioTarget, "duration", { value: 100, configurable: true })

    const leftEvent = new KeyboardEvent("keydown", { key: "ArrowLeft", bubbles: true, cancelable: true })
    window.dispatchEvent(leftEvent)
    expect(controller.audioTarget.currentTime).toBe(5)
    expect(leftEvent.defaultPrevented).toBe(true)

    const rightEvent = new KeyboardEvent("keydown", { key: "ArrowRight", bubbles: true, cancelable: true })
    window.dispatchEvent(rightEvent)
    expect(controller.audioTarget.currentTime).toBe(10)
    expect(rightEvent.defaultPrevented).toBe(true)
  })

  it("triggers previous and next on Shift+ArrowLeft and Shift+ArrowRight (R7)", () => {
    controller.loadTrack({ source: "/audio/track.mp3", title: "Track", artist: "Artist" })
    vi.spyOn(controller, "previous").mockImplementation(() => {})
    vi.spyOn(controller, "next").mockImplementation(() => {})

    const shiftLeft = new KeyboardEvent("keydown", { key: "ArrowLeft", shiftKey: true, bubbles: true, cancelable: true })
    window.dispatchEvent(shiftLeft)
    expect(controller.previous).toHaveBeenCalled()
    expect(shiftLeft.defaultPrevented).toBe(true)

    const shiftRight = new KeyboardEvent("keydown", { key: "ArrowRight", shiftKey: true, bubbles: true, cancelable: true })
    window.dispatchEvent(shiftRight)
    expect(controller.next).toHaveBeenCalled()
    expect(shiftRight.defaultPrevented).toBe(true)
  })

  it("toggles mute and restores volume on M key press or mute button click (R7, R9)", () => {
    controller.loadTrack({ source: "/audio/track.mp3", title: "Track", artist: "Artist" })
    controller.audioTarget.volume = 0.7
    controller.updateVolumeControls(0.7)
    const muteBtn = document.querySelector("[data-player-target='muteButton']")

    // 1. Press 'm' to mute
    const mEvent = new KeyboardEvent("keydown", { key: "m", bubbles: true, cancelable: true })
    window.dispatchEvent(mEvent)
    expect(mEvent.defaultPrevented).toBe(true)
    expect(controller.audioTarget.volume).toBe(0)
    expect(muteBtn.getAttribute("aria-label")).toBe("Unmute")

    // 2. Click mute button to unmute
    controller.toggleMute()
    expect(controller.audioTarget.volume).toBe(0.7)
    expect(muteBtn.getAttribute("aria-label")).toBe("Mute")
  })

  function addLyricsTargets() {
    document.querySelector("[data-controller='player']").insertAdjacentHTML("beforeend", `
      <button data-player-target="queueTab"></button><button data-player-target="lyricsTab"></button>
      <div data-player-target="queueView"></div><div data-player-target="lyricsView" hidden></div>
      <p data-player-target="lyricsStatus"></p><ol data-player-target="lyricsList"></ol><button data-player-target="lyricsFollow" hidden></button>
    `)
  }
})
