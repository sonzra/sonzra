import { Application } from "@hotwired/stimulus"
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import CardOptionsController from "../../app/javascript/controllers/card_options_controller.js"
import { OfflineMediaStore } from "../../app/javascript/offline_media_store.js"
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
        <button data-card-options-target="offlineAction"></button>
        <button data-card-options-target="deletePlaylistAction" data-card-options-delete-playlist-url="/server_connections/1/playlists/playlist-7"></button>
        <span data-card-options-target="favoriteLabel"></span>
        <span data-card-options-target="offlineLabel"></span>
        <div data-card-options-target="loader" hidden></div>
        <p data-card-options-target="loaderMessage"></p>
        <button data-card-options-target="loaderCancel" hidden></button>
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

  it("downloads a playable item for offline use and confirms it", async () => {
    const cache = { match: vi.fn(async () => undefined), put: vi.fn(async () => {}) }
    const cacheStorage = { open: vi.fn(async () => cache) }
    const values = new Map()
    const storage = { getItem: (key) => values.get(key) || null, setItem: (key, value) => values.set(key, value), removeItem: (key) => values.delete(key) }
    cardOptionsController.cachedOfflineStore = new OfflineMediaStore({ cacheStorage, storage, fetcher: fetchMock })
    fetchMock.mockResolvedValueOnce({ ok: true, clone: () => ({ cached: true }) })
    const playButton = document.createElement("button")
    playButton.dataset.playerSourceParam = "/server_connections/1/audio/track-1"
    playButton.dataset.playerTitleParam = "Offline track"

    await cardOptionsController.configureOfflineAction(playButton)
    await cardOptionsController.downloadForOffline({ type: "click", preventDefault() {}, stopPropagation() {} })
    expect(cache.put).toHaveBeenCalledWith("/server_connections/1/audio/track-1", expect.any(Object))
    expect(document.querySelector("[data-card-options-target='offlineLabel']").textContent).toBe("Available offline")
    expect(document.querySelector("[data-player-target='queueFeedback']").textContent).toBe("Available offline")
  })

  it("downloads every item from an album or playlist queue", async () => {
    const cache = { match: vi.fn(async () => undefined), put: vi.fn(async () => {}) }
    const cacheStorage = { open: vi.fn(async () => cache) }
    const values = new Map()
    const storage = { getItem: (key) => values.get(key) || null, setItem: (key, value) => values.set(key, value), removeItem: (key) => values.delete(key) }
    fetchMock.mockImplementation(async (url) => {
      if (url === "/server_connections/1/playback_queues/album-1") return { ok: true, json: async () => ({ items: [ { source: "/server_connections/1/audio/one", title: "One", album_id: "album-1", album: "Saved album", album_artist: "Artist" }, { source: "/server_connections/1/audio/two", title: "Two", album_id: "album-1", album: "Saved album", album_artist: "Artist" } ] }) }
      return { ok: true, clone: () => ({ cached: true }) }
    })
    cardOptionsController.cachedOfflineStore = new OfflineMediaStore({ cacheStorage, storage, fetcher: fetchMock })
    const card = document.createElement("article")
    card.className = "listen-card"
    card.innerHTML = '<a class="listen-card__art"></a>'
    const playButton = document.createElement("button")
    playButton.className = "listen-card__play"
    playButton.dataset.playerQueueUrlParam = "/server_connections/1/playback_queues/album-1"
    card.append(playButton)
    document.body.append(card)
    cardOptionsController.activeCard = card

    await cardOptionsController.configureOfflineAction(playButton)
    await cardOptionsController.downloadForOffline({ type: "click", preventDefault() {}, stopPropagation() {} })

    expect(cache.put).toHaveBeenCalledWith("/server_connections/1/audio/one", expect.any(Object))
    expect(cache.put).toHaveBeenCalledWith("/server_connections/1/audio/two", expect.any(Object))
    expect(cardOptionsController.cachedOfflineStore.collectionDownloaded("/server_connections/1/playback_queues/album-1")).toBe(true)
    expect(card.querySelector(".listen-card__offline-indicator").title).toBe("Available offline")
    expect(card.querySelector(".listen-card__offline-indicator svg")).not.toBeNull()
    expect(cardOptionsController.cachedOfflineStore.catalog()[0]).toMatchObject({ albumId: "album-1", album: "Saved album" })
    expect(document.querySelector("[data-player-target='queueFeedback']").textContent).toBe("2 items available offline")
  })

  it("shows a per-card download ring instead of blocking the library", () => {
    const card = document.createElement("article")
    card.innerHTML = '<a class="listen-card__art"></a>'

    cardOptionsController.setDownloadProgress(card, 2, 4)

    const ring = card.querySelector(".listen-card__download-progress")
    expect(ring.style.getPropertyValue("--progress")).toBe("50%")
    expect(ring.title).toBe("Downloading 2 of 4")
  })

  it("shows previously downloaded collections as available offline", async () => {
    const card = document.createElement("article")
    card.className = "listen-card"
    card.innerHTML = '<a class="listen-card__art"></a><button class="listen-card__play" data-player-queue-url-param="/server_connections/1/playback_queues/album-1"></button>'
    document.body.append(card)
    cardOptionsController.cachedOfflineStore = { collectionDownloaded: vi.fn(() => true) }

    await cardOptionsController.configureOfflineAction(card.querySelector(".listen-card__play"))

    expect(document.querySelector("[data-card-options-target='offlineAction']").disabled).toBe(true)
    expect(document.querySelector("[data-card-options-target='offlineLabel']").textContent).toBe("Available offline")
    expect(card.querySelector(".listen-card__offline-indicator").title).toBe("Available offline")
  })

  it("reports an unexpected offline download error with useful detail", () => {
    expect(cardOptionsController.offlineDownloadErrorMessage(new TypeError("downloadAll is not a function"))).toBe("Sonzra couldn’t download this item: downloadAll is not a function")
  })
})
