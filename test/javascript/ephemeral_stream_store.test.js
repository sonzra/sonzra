import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import { EphemeralStreamStore, STREAM_CACHE_NAME } from "../../app/javascript/ephemeral_stream_store.js"

describe("ephemeral stream store", () => {
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

  it("stores audio responses and records them in the index", async () => {
    const store = new EphemeralStreamStore({ cacheStorage, storage })
    const response = mockResponse(5_000_000)

    await store.put("/server_connections/1/audio/track-1", response)

    expect(cacheStorage.open).toHaveBeenCalledWith(STREAM_CACHE_NAME)
    expect(cache.put).toHaveBeenCalledWith("/server_connections/1/audio/track-1", expect.any(Object))
    await expect(store.has("/server_connections/1/audio/track-1")).resolves.toBe(true)
    expect(store.index()).toHaveLength(1)
    expect(store.index()[0]).toMatchObject({
      source: "/server_connections/1/audio/track-1",
      size: 5_000_000
    })
  })

  it("updates access timestamp when touch is called", async () => {
    const store = new EphemeralStreamStore({ cacheStorage, storage })
    await store.put("/server_connections/1/audio/track-1", mockResponse(1000))
    const initialTime = store.index()[0].accessedAt

    await new Promise((r) => setTimeout(r, 10))
    store.touch("/server_connections/1/audio/track-1")

    expect(store.index()[0].accessedAt).toBeGreaterThanOrEqual(initialTime)
  })

  it("evicts oldest items when max track count is exceeded", async () => {
    const store = new EphemeralStreamStore({ cacheStorage, storage, maxTracks: 2 })

    await store.put("/audio/track-1", mockResponse(1000))
    await new Promise((r) => setTimeout(r, 5))
    await store.put("/audio/track-2", mockResponse(1000))
    await new Promise((r) => setTimeout(r, 5))
    await store.put("/audio/track-3", mockResponse(1000))

    expect(cache.delete).toHaveBeenCalledWith("/audio/track-1")
    await expect(store.has("/audio/track-1")).resolves.toBe(false)
    await expect(store.has("/audio/track-2")).resolves.toBe(true)
    await expect(store.has("/audio/track-3")).resolves.toBe(true)
    expect(store.index().map((item) => item.source)).toEqual(["/audio/track-2", "/audio/track-3"])
  })

  it("evicts oldest items when max byte budget is exceeded", async () => {
    const store = new EphemeralStreamStore({ cacheStorage, storage, maxBytes: 10_000_000 })

    await store.put("/audio/track-1", mockResponse(6_000_000))
    await new Promise((r) => setTimeout(r, 5))
    await store.put("/audio/track-2", mockResponse(6_000_000))

    expect(cache.delete).toHaveBeenCalledWith("/audio/track-1")
    await expect(store.has("/audio/track-1")).resolves.toBe(false)
    await expect(store.has("/audio/track-2")).resolves.toBe(true)
  })

  it("can evict a specific track and clear entire store", async () => {
    const store = new EphemeralStreamStore({ cacheStorage, storage })
    await store.put("/audio/track-1", mockResponse(1000))
    await store.put("/audio/track-2", mockResponse(1000))

    await store.evict("/audio/track-1")
    expect(cache.delete).toHaveBeenCalledWith("/audio/track-1")
    await expect(store.has("/audio/track-1")).resolves.toBe(false)

    await store.clear()
    expect(cacheStorage.delete).toHaveBeenCalledWith(STREAM_CACHE_NAME)
    expect(store.index()).toEqual([])
  })

  function mockResponse(contentLength = 0) {
    const headers = new Headers()
    if (contentLength > 0) headers.set("Content-Length", String(contentLength))
    return {
      headers,
      clone: vi.fn(() => ({ cloned: true }))
    }
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
