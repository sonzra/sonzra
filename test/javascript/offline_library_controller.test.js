import { describe, expect, it, vi } from "vitest"
import OfflineLibraryController from "../../app/javascript/controllers/offline_library_controller.js"

describe("offline library controller", () => {
  it("groups downloaded tracks by album, including albums with one saved track", () => {
    const controller = Object.create(OfflineLibraryController.prototype)
    controller.store = () => ({
      catalog: () => [
        { source: "/audio/one", title: "One", albumId: "album-1", album: "First album", albumArtist: "Artist", downloadedAt: "2026-08-10T10:00:00Z" },
        { source: "/audio/two", title: "Two", albumId: "album-1", album: "First album", albumArtist: "Artist", downloadedAt: "2026-08-10T10:01:00Z" },
        { source: "/audio/three", title: "Three", albumId: "album-2", album: "Second album", albumArtist: "Another artist", downloadedAt: "2026-08-10T10:02:00Z" }
      ],
      collections: () => []
    })

    const albums = controller.albums()

    expect(albums).toHaveLength(2)
    expect(albums[0]).toMatchObject({ title: "Second album", tracks: [ { title: "Three" } ] })
    expect(albums[1]).toMatchObject({ title: "First album" })
    expect(albums[1].tracks).toHaveLength(2)
  })

  it("plays only the downloaded tracks that belong to the selected album", () => {
    const controller = Object.create(OfflineLibraryController.prototype)
    const player = { setOfflineQueue: vi.fn() }
    controller.albumFor = () => ({ key: "album-1", tracks: [ { source: "/audio/one" }, { source: "/audio/two" } ] })
    controller.playerController = () => player

    controller.playAlbum({ currentTarget: { dataset: { offlineAlbumKey: "album-1" } } })

    expect(player.setOfflineQueue).toHaveBeenCalledWith([
      { source: "/audio/one" },
      { source: "/audio/two" }
    ], { autoplay: true })
  })

  it("shows album removal from the same overflow menu used by library cards", () => {
    const controller = Object.create(OfflineLibraryController.prototype)
    const card = controller.albumCard({ key: "album-1", title: "First album", artist: "Artist", tracks: [ {} ] })
    const toggle = card.querySelector(".listen-card__options-toggle")
    const menu = card.querySelector(".offline-downloads__album-menu")

    expect(menu.hidden).toBe(true)
    toggle.click()

    expect(toggle.getAttribute("aria-expanded")).toBe("true")
    expect(menu.hidden).toBe(false)
    expect(menu.querySelector("button").textContent).toBe("Remove")
  })

  it("removes every track when removing a downloaded album", async () => {
    const controller = Object.create(OfflineLibraryController.prototype)
    const removeAll = vi.fn(async () => {})
    controller.albumFor = vi.fn(() => ({ key: "album-1", tracks: [ { source: "/audio/one" }, { source: "/audio/two" } ] }))
    controller.store = vi.fn(() => ({ removeAll }))
    controller.renderAlbums = vi.fn()

    await controller.removeAlbum({ currentTarget: { dataset: { offlineAlbumKey: "album-1" }, disabled: false } })

    expect(removeAll).toHaveBeenCalledWith([ "/audio/one", "/audio/two" ])
    expect(controller.renderAlbums).toHaveBeenCalledOnce()
  })

  it("reports only used browser storage", async () => {
    const controller = Object.create(OfflineLibraryController.prototype)
    controller.hasStorageTarget = true
    controller.storageTarget = document.createElement("p")
    controller.store = () => ({ storageEstimate: async () => ({ usage: 1_572_864, quota: 10_485_760 }) })

    await controller.refreshStorageEstimate()

    expect(controller.storageTarget.textContent).toBe("This browser uses 1.5 MB for Sonzra and other site data")
  })

  it("hides the downloads grid before showing an album detail view", () => {
    const controller = Object.create(OfflineLibraryController.prototype)
    Object.defineProperties(controller, {
      element: { value: document.createElement("main") },
      introTarget: { value: document.createElement("section") },
      detailBackTarget: { value: document.createElement("button") },
      descriptionTarget: { value: document.createElement("p") },
      storageTarget: { value: document.createElement("p") },
      emptyTarget: { value: document.createElement("section") },
      listTarget: { value: document.createElement("ol") },
      detailHeroTarget: { value: document.createElement("section") },
      trackSectionTarget: { value: document.createElement("section") },
      trackListTarget: { value: document.createElement("ol") }
    })
    controller.albumFor = () => ({ key: "album-1", title: "First album", artist: "Artist", tracks: [] })
    controller.renderAlbumHero = vi.fn()

    controller.renderAlbum("album-1")

    expect(controller.introTarget.hidden).toBe(true)
    expect(controller.listTarget.hidden).toBe(true)
    expect(controller.detailHeroTarget.hidden).toBe(false)
    expect(controller.trackSectionTarget.hidden).toBe(false)
  })
})
