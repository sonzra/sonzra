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
      <div data-controller="player" data-player-radio-enabled-value="false" data-player-preferences-url-value="/player_preferences">
        <aside data-player-target="shell" hidden>
          <audio data-player-target="audio"></audio>
          <img data-player-target="artwork" src="/brand/sonzra-mark.svg" alt="">
          <strong data-player-target="title">Choose something to play</strong>
          <span data-player-target="artist">Your player will stay here</span>
          <button data-player-target="toggle"></button>
          <button data-player-target="radio"></button>
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

  it("keeps the minimized progress indicator in sync with playback", () => {
    controller.updateProgress(30, 120)

    expect(document.querySelector("[data-player-target='miniProgress']").style.width).toBe("25%")
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

  it("keeps grouped lyric text under one synchronized highlight", () => {
    addLyricsTargets()
    controller.currentLyrics = { available: true, synchronized: true, lines: [ { text: "First line\nSecond line", start: 10 } ] }
    controller.audioTarget.currentTime = 11

    controller.renderLyrics(controller.currentLyrics)

    const group = document.querySelector("[data-player-target='lyricsList'] li")
    expect(group.classList).toContain("listen-queue__lyric-group")
    expect(group.classList).toContain("is-current-lyric")
    expect(group.querySelectorAll(".listen-queue__lyric-line")).toHaveLength(2)
  })

  it("shows an unavailable message when the server has no usable lyrics", () => {
    addLyricsTargets()

    controller.renderLyrics({ available: false, synchronized: false, lines: [] })

    expect(document.querySelector("[data-player-target='lyricsStatus']").textContent).toBe("Lyrics aren’t available for this track.")
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
    expect(document.querySelector("[data-player-target='queueFeedback']").textContent).toBe("Radio on")
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

  function addLyricsTargets() {
    document.querySelector("[data-controller='player']").insertAdjacentHTML("beforeend", `
      <button data-player-target="queueTab"></button><button data-player-target="lyricsTab"></button>
      <div data-player-target="queueView"></div><div data-player-target="lyricsView" hidden></div>
      <p data-player-target="lyricsStatus"></p><ol data-player-target="lyricsList"></ol><button data-player-target="lyricsFollow" hidden></button>
    `)
  }
})
