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
      <div data-controller="player">
        <aside data-player-target="shell" hidden>
          <audio data-player-target="audio"></audio>
          <img data-player-target="artwork" src="/brand/sonzra-mark.svg" alt="">
          <strong data-player-target="title">Choose something to play</strong>
          <span data-player-target="artist">Your player will stay here</span>
          <button data-player-target="toggle"></button>
          <span data-player-target="miniProgress"></span>
        </aside>
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
      queueOpen: false
    })
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
  })
})
