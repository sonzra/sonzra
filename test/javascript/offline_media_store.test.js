import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import { OfflineMediaStore, OfflineMediaStoreError } from "../../app/javascript/offline_media_store.js"

describe("offline media store", () => {
  let entries
  let storage
  let cache
  let cacheStorage

  beforeEach(() => {
    entries = new Map()
    storage = new MapStorage()
    cache = {
      match: vi.fn(async (key) => entries.get(key)),
      put: vi.fn(async (key, response) => entries.set(key, response)),
      delete: vi.fn(async (key) => entries.delete(key))
    }
    cacheStorage = {
      open: vi.fn(async () => cache),
      delete: vi.fn(async () => entries.clear())
    }
  })

  afterEach(() => {
    vi.restoreAllMocks()
    vi.unstubAllGlobals()
  })

  it("stores audio, artwork, and the device-local catalog", async () => {
    const response = responseWithClone()
    const fetcher = vi.fn(async () => response)
    const store = new OfflineMediaStore({ scope: "user-1", cacheStorage, storage, fetcher })

    await store.download({ source: "/server_connections/1/audio/track-1", artwork: "/server_connections/1/artwork/album-1", title: "Track" })

    expect(cache.put).toHaveBeenNthCalledWith(1, "/server_connections/1/audio/track-1", expect.any(Object))
    expect(cache.put).toHaveBeenNthCalledWith(2, "/server_connections/1/artwork/album-1", response)
    expect(store.catalog()).toEqual([ expect.objectContaining({ source: "/server_connections/1/audio/track-1", title: "Track" }) ])
    await expect(store.downloaded("/server_connections/1/audio/track-1")).resolves.toBe(true)
  })

  it("keeps existing downloads scoped to the device user and clears them at sign out", async () => {
    const store = new OfflineMediaStore({ scope: "user-1", cacheStorage, storage, fetcher: vi.fn(async () => responseWithClone()) })
    await store.download({ source: "/server_connections/1/audio/track-1" })

    await store.clear()

    expect(cacheStorage.delete).toHaveBeenCalledWith("sonzra-offline-media-v1")
    expect(cacheStorage.delete).toHaveBeenCalledWith("sonzra-offline-shell-v2")
    expect(store.catalog()).toEqual([])
  })

  it("caches the authenticated player shell for offline fallback", async () => {
    const response = responseWithClone()
    const store = new OfflineMediaStore({ scope: "user-1", cacheStorage, storage, fetcher: vi.fn(async () => response) })

    await store.warmOfflineShell()

    expect(cacheStorage.open).toHaveBeenCalledWith("sonzra-offline-shell-v2")
    expect(cache.put).toHaveBeenCalledWith("/offline_shell", expect.any(Object))
  })

  it("retains already-loaded app assets with the offline shell", async () => {
    const response = responseWithClone()
    const assetUrl = `${location.origin}/assets/application.js`
    vi.stubGlobal("performance", { getEntriesByType: () => [ { name: assetUrl }, { name: "http://example.test/ignored.js" } ] })
    const fetcher = vi.fn(async () => response)
    const store = new OfflineMediaStore({ scope: "user-1", cacheStorage, storage, fetcher })

    await store.warmOfflineShell()

    expect(cacheStorage.open).toHaveBeenCalledWith("sonzra-offline-assets-v1")
    expect(cache.put).toHaveBeenCalledWith(assetUrl, response)
  })

  it("removes a downloaded item and its unused artwork copy", async () => {
    const store = new OfflineMediaStore({ scope: "user-1", cacheStorage, storage, fetcher: vi.fn(async () => responseWithClone()) })
    await store.download({ source: "/server_connections/1/audio/track-1", artwork: "/server_connections/1/artwork/album-1" })

    await store.remove("/server_connections/1/audio/track-1")

    expect(cache.delete).toHaveBeenCalledWith("/server_connections/1/audio/track-1")
    expect(cache.delete).toHaveBeenCalledWith("/server_connections/1/artwork/album-1")
    expect(store.catalog()).toEqual([])
  })

  it("removes a whole album atomically without leaving its other tracks behind", async () => {
    const store = new OfflineMediaStore({ scope: "user-1", cacheStorage, storage, fetcher: vi.fn(async () => responseWithClone()) })
    await store.download({ source: "/audio/one" })
    await store.download({ source: "/audio/two" })
    store.saveCollection("/playback_queues/album-1", [ { source: "/audio/one" }, { source: "/audio/two" } ], { title: "Album" })

    await store.removeAll([ "/audio/one", "/audio/two" ])

    expect(store.catalog()).toEqual([])
    expect(store.collections()).toEqual([])
    expect(cache.delete).toHaveBeenCalledWith("/audio/one")
    expect(cache.delete).toHaveBeenCalledWith("/audio/two")
  })

  it("downloads a collection one item at a time and skips existing copies", async () => {
    const store = new OfflineMediaStore({ scope: "user-1", cacheStorage, storage, fetcher: vi.fn(async () => responseWithClone()) })
    const progress = vi.fn()

    const downloaded = await store.downloadAll([ { source: "/audio/one" }, { source: "/audio/two" } ], progress)
    const repeated = await store.downloadAll([ { source: "/audio/one" }, { source: "/audio/two" } ], progress)

    expect(downloaded).toBe(2)
    expect(repeated).toBe(0)
    expect(progress).toHaveBeenLastCalledWith(2, 2)
  })

  it("stops a collection download as soon as the user cancels it", async () => {
    const abortController = new AbortController()
    const fetcher = vi.fn(async (_url, { signal }) => {
      if (signal?.aborted) throw new DOMException("Cancelled", "AbortError")
      return responseWithClone()
    })
    const store = new OfflineMediaStore({ scope: "user-1", cacheStorage, storage, fetcher })

    await expect(store.downloadAll([ { source: "/audio/one" }, { source: "/audio/two" } ], (completed) => {
      if (completed === 1) abortController.abort()
    }, { signal: abortController.signal })).rejects.toMatchObject({ name: "AbortError" })

    expect(store.catalog()).toEqual([ expect.objectContaining({ source: "/audio/one" }) ])
    expect(fetcher).toHaveBeenCalledTimes(1)
  })

  it("records complete collection downloads and clears that state when an item is removed", async () => {
    const store = new OfflineMediaStore({ scope: "user-1", cacheStorage, storage, fetcher: vi.fn(async () => responseWithClone()) })
    const source = "/audio/one"

    await store.download({ source })
    store.saveCollection("/playback_queues/album-1", [ { source } ], { title: "Album" })

    expect(store.collectionDownloaded("/playback_queues/album-1")).toBe(true)
    expect(store.collections()).toContainEqual(expect.objectContaining({ title: "Album" }))

    await store.remove(source)

    expect(store.collectionDownloaded("/playback_queues/album-1")).toBe(false)
  })

  it("reports a helpful error when the browser cannot cache media", async () => {
    const store = new OfflineMediaStore({ scope: "user-1", cacheStorage: null, storage, fetcher: vi.fn() })

    await expect(store.download({ source: "/audio/track-1" })).rejects.toBeInstanceOf(OfflineMediaStoreError)
  })

  it("does not open Cache Storage before downloading a new item", async () => {
    const store = new OfflineMediaStore({ scope: "user-1", cacheStorage, storage, fetcher: vi.fn(async () => responseWithClone()) })

    await expect(store.downloaded("/audio/new-item")).resolves.toBe(false)

    expect(cacheStorage.open).not.toHaveBeenCalled()
  })

  it("requests persistent browser storage when it is available", async () => {
    const persist = vi.fn(async () => true)
    const originalStorage = navigator.storage
    Object.defineProperty(navigator, "storage", { configurable: true, value: { persist } })
    const store = new OfflineMediaStore({ scope: "user-1", cacheStorage, storage, fetcher: vi.fn() })

    await expect(store.requestPersistentStorage()).resolves.toBe(true)
    expect(persist).toHaveBeenCalledOnce()
    Object.defineProperty(navigator, "storage", { configurable: true, value: originalStorage })
  })

  it("invokes the browser fetch function through its global receiver", async () => {
    const browser = { fetch: vi.fn(async () => responseWithClone()) }
    const store = new OfflineMediaStore({
      scope: "user-1",
      cacheStorage,
      storage,
      fetcher: (...arguments_) => browser.fetch(...arguments_)
    })

    await store.download({ source: "/audio/track-1" })

    expect(browser.fetch).toHaveBeenCalledWith("/audio/track-1", { credentials: "same-origin" })
  })

  function responseWithClone() {
    return { ok: true, clone: vi.fn(() => ({ cached: true })) }
  }
})

class MapStorage {
  constructor() {
    this.values = new Map()
  }

  getItem(key) {
    return this.values.get(key) || null
  }

  setItem(key, value) {
    this.values.set(key, value)
  }

  removeItem(key) {
    this.values.delete(key)
  }
}
