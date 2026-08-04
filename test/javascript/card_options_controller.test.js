import { Application } from "@hotwired/stimulus"
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import CardOptionsController from "../../app/javascript/controllers/card_options_controller.js"
import PlayerController from "../../app/javascript/controllers/player_controller.js"

describe("card options controller", () => {
  let application
  let cardOptionsController
  let fetchMock

  beforeEach(async () => {
    vi.useFakeTimers()
    vi.stubGlobal("requestAnimationFrame", (callback) => callback())
    vi.spyOn(HTMLMediaElement.prototype, "pause").mockImplementation(() => {})
    HTMLDialogElement.prototype.showModal = function showModal() {
      this.open = true
    }
    HTMLDialogElement.prototype.close = function close() {
      this.open = false
    }
    fetchMock = vi.fn(async (url, options = {}) => {
      if (options.method === "POST" && url === "/server_connections/1/playlists") {
        return { ok: true, json: async () => ({ id: "playlist-1" }) }
      }
      if (options.method === "POST") return { ok: true }
      return {
        ok: true,
        json: async () => [ { Id: "playlist-1", Name: "Road trip" } ]
      }
    })
    vi.stubGlobal("fetch", fetchMock)
    document.body.innerHTML = `
      <div data-controller="player card-options">
        <aside data-player-target="shell" hidden>
          <audio data-player-target="audio"></audio>
          <img data-player-target="artwork" src="/brand/sonzra-mark.svg" alt="">
          <strong data-player-target="title">Choose something to play</strong>
          <span data-player-target="artist">Your player will stay here</span>
          <button data-player-target="toggle"></button>
          <span data-player-target="miniProgress"></span>
          <p data-player-target="queueFeedback" hidden></p>
        </aside>
        <button
          data-card-options-target="playlistAction"
          data-card-options-playlists-url="/server_connections/1/playlists"
          data-card-options-item-id="track-1"
          data-card-options-item-type="Audio"
        ></button>
        <section data-card-options-target="sheet" hidden></section>
        <div data-card-options-target="panel"></div>
        <button data-card-options-target="queueAction"></button>
        <button data-card-options-target="resetAction"></button>
        <button data-card-options-target="favoriteAction"></button>
        <button data-card-options-target="deletePlaylistAction" data-card-options-delete-playlist-url="/server_connections/1/playlists/playlist-7"></button>
        <span data-card-options-target="favoriteLabel"></span>
        <div data-card-options-target="loader" hidden></div>
        <p data-card-options-target="loaderMessage"></p>
        <dialog data-card-options-target="playlistDialog"></dialog>
        <ol data-card-options-target="playlistList"></ol>
        <input data-card-options-target="playlistName">
        <p data-card-options-target="playlistFeedback"></p>
      </div>
    `
    application = Application.start()
    application.register("player", PlayerController)
    application.register("card-options", CardOptionsController)
    await Promise.resolve()
    cardOptionsController = application.getControllerForElementAndIdentifier(document.querySelector("[data-controller='player card-options']"), "card-options")
  })

  afterEach(() => {
    application?.stop()
    vi.useRealTimers()
    vi.unstubAllGlobals()
    vi.restoreAllMocks()
  })

  it("adds the selected track to a playlist and shows a toast confirmation", async () => {
    await cardOptionsController.openPlaylistPicker()

    document.querySelector(".playlist-picker__choice").click()
    await Promise.resolve()
    await Promise.resolve()
    vi.runAllTimers()

    expect(fetchMock).toHaveBeenNthCalledWith(1, "/server_connections/1/playlists", { headers: { Accept: "application/json" } })
    expect(fetchMock).toHaveBeenNthCalledWith(
      2,
      "/server_connections/1/playlists/playlist-1/items",
      expect.objectContaining({
        method: "POST",
        body: JSON.stringify({ item_id: "track-1", item_type: "Audio" })
      })
    )
    expect(document.querySelector("[data-player-target='queueFeedback']").textContent).toBe("Track added to playlist")
  })

  it("creates a playlist before adding the selected track", async () => {
    await cardOptionsController.openPlaylistPicker()

    document.querySelector("[data-card-options-target='playlistName']").value = "Road trip"
    await cardOptionsController.createPlaylist({ preventDefault() {} })
    await Promise.resolve()
    await Promise.resolve()

    expect(fetchMock).toHaveBeenNthCalledWith(
      2,
      "/server_connections/1/playlists",
      expect.objectContaining({
        method: "POST",
        body: JSON.stringify({ name: "Road trip" })
      })
    )
    expect(fetchMock).toHaveBeenNthCalledWith(
      3,
      "/server_connections/1/playlists/playlist-1/items",
      expect.objectContaining({
        method: "POST",
        body: JSON.stringify({ item_id: "track-1", item_type: "Audio" })
      })
    )
  })

  it("accepts a playlist object when creating a playlist", async () => {
    fetchMock.mockImplementationOnce(async () => ({
      ok: true,
      json: async () => [ { Id: "playlist-1", Name: "Road trip" } ]
    })).mockImplementationOnce(async () => ({
      ok: true,
      json: async () => ({ Id: "playlist-2" })
    })).mockImplementationOnce(async () => ({ ok: true }))

    await cardOptionsController.openPlaylistPicker()

    document.querySelector("[data-card-options-target='playlistName']").value = "Late night"
    await cardOptionsController.createPlaylist({ preventDefault() {} })
    await Promise.resolve()
    await Promise.resolve()

    expect(fetchMock).toHaveBeenNthCalledWith(
      3,
      "/server_connections/1/playlists/playlist-2/items",
      expect.objectContaining({
        method: "POST",
        body: JSON.stringify({ item_id: "track-1", item_type: "Audio" })
      })
    )
  })

  it("opens the playlist modal before the playlists request resolves", async () => {
    let resolveFetch
    fetchMock.mockImplementationOnce(() => new Promise((resolve) => { resolveFetch = resolve }))

    const openPromise = cardOptionsController.openPlaylistPicker()

    expect(document.querySelector("[data-card-options-target='playlistDialog']").open).toBe(true)
    expect(document.querySelector(".playlist-picker__loading").textContent).toBe("Loading playlists…")

    resolveFetch({ ok: true, json: async () => [ { Id: "playlist-1", Name: "Road trip" } ] })
    await openPromise

    expect(document.querySelector(".playlist-picker__choice").textContent).toContain("Road trip")
  })

  it("opens the playlist modal for a queued track", async () => {
    cardOptionsController.openPlaylistPickerForItem({
      playlistsUrl: "/server_connections/1/playlists",
      itemId: "queued-track-1"
    })
    await Promise.resolve()

    expect(document.querySelector("[data-card-options-target='playlistDialog']").open).toBe(true)
    expect(document.querySelector("[data-card-options-target='playlistAction']").dataset.cardOptionsItemId).toBe("queued-track-1")
    expect(fetchMock).toHaveBeenCalledWith("/server_connections/1/playlists", { headers: { Accept: "application/json" } })
  })

  it("adds a whole album to a playlist", async () => {
    document.querySelector("[data-card-options-target='playlistAction']").dataset.cardOptionsItemId = "album-1"
    document.querySelector("[data-card-options-target='playlistAction']").dataset.cardOptionsItemType = "MusicAlbum"

    await cardOptionsController.openPlaylistPicker()

    document.querySelector(".playlist-picker__choice").click()
    await Promise.resolve()
    await Promise.resolve()

    expect(fetchMock).toHaveBeenNthCalledWith(
      2,
      "/server_connections/1/playlists/playlist-1/items",
      expect.objectContaining({
        method: "POST",
        body: JSON.stringify({ item_id: "album-1", item_type: "MusicAlbum" })
      })
    )
    expect(document.querySelector("[data-player-target='queueFeedback']").textContent).toBe("Album added to playlist")
  })

  it("deletes a playlist and removes the current card", async () => {
    fetchMock.mockImplementationOnce(async () => ({ ok: true }))
    const card = document.createElement("article")
    card.className = "listen-card"
    document.body.append(card)
    cardOptionsController.activeCard = card

    await cardOptionsController.deletePlaylist({
      type: "click",
      preventDefault() {},
      stopPropagation() {}
    })

    expect(fetchMock).toHaveBeenCalledWith(
      "/server_connections/1/playlists/playlist-7",
      expect.objectContaining({ method: "DELETE" })
    )
    expect(document.querySelector("[data-player-target='queueFeedback']").textContent).toBe("Playlist deleted")
    expect(card.isConnected).toBe(false)
  })

  it("hides the delete playlist action for non-playlist cards", () => {
    document.body.insertAdjacentHTML("beforeend", `
      <article class="listen-card">
        <button class="listen-card__play" data-player-source-param="/server_connections/1/audio/track-1"></button>
        <div class="listen-card__options"
          data-card-options-favorite-url="/server_connections/1/favorites/track-1"
          data-card-options-favorite="false"
          data-card-options-playlists-url="/server_connections/1/playlists"
          data-card-options-item-id="track-1"></div>
      </article>
    `)
    const audioPlayButton = document.querySelector(".listen-card:last-of-type .listen-card__play")

    cardOptionsController.configureQueueAction(audioPlayButton)

    expect(document.querySelector("[data-card-options-target='deletePlaylistAction']").hidden).toBe(true)
    expect(document.querySelector("[data-card-options-target='deletePlaylistAction']").dataset.cardOptionsDeletePlaylistUrl).toBe("")
  })
})
