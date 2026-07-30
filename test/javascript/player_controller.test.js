import { Application } from "@hotwired/stimulus"
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import PlayerController from "../../app/javascript/controllers/player_controller.js"

describe("player controller", () => {
  let application
  let controller

  beforeEach(async () => {
    sessionStorage.clear()
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
    application.stop()
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

  it("persists the current queue for a restored player", () => {
    controller.queue = [ { source: "/audio/track.mp3", title: "A track", artist: "An artist" } ]
    controller.currentIndex = 0

    controller.persistQueue()

    expect(JSON.parse(sessionStorage.getItem("sonzra:queue"))).toEqual(controller.queue)
    expect(sessionStorage.getItem("sonzra:queue-index")).toBe("0")
  })
})
