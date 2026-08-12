import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"

describe("offline service worker", () => {
  let handlers
  let cache

  beforeEach(async () => {
    handlers = {}
    cache = { match: vi.fn(async () => undefined), put: vi.fn(async () => undefined) }
    vi.stubGlobal("self", {
      addEventListener: (name, handler) => { handlers[name] = handler },
      skipWaiting: vi.fn(),
      clients: { claim: vi.fn() },
      location: { origin: "http://sonzra.test" }
    })
    vi.stubGlobal("caches", { open: vi.fn(async () => cache) })
    vi.stubGlobal("fetch", vi.fn(async () => ({ network: true })))

    vi.resetModules()
    await import("../../public/service-worker.js")
  })

  afterEach(() => {
    vi.unstubAllGlobals()
  })

  it("serves a downloaded audio copy before attempting the network", async () => {
    const downloadedAudio = { offline: true }
    cache.match.mockResolvedValue(downloadedAudio)
    const event = requestEvent("http://sonzra.test/server_connections/1/audio/track-1")

    handlers.fetch(event)

    await expect(event.response).resolves.toBe(downloadedAudio)
    expect(fetch).not.toHaveBeenCalled()
  })

  it("uses the normal stream when no offline copy exists", async () => {
    const event = requestEvent("http://sonzra.test/server_connections/1/audio/track-1")

    handlers.fetch(event)

    await expect(event.response).resolves.toEqual({ network: true })
    expect(fetch).toHaveBeenCalledWith(event.request)
  })

  it("falls back to the normal stream when offline cache access fails", async () => {
    caches.open.mockRejectedValue(new Error("Cache unavailable"))
    const event = requestEvent("http://sonzra.test/server_connections/1/audio/track-1")

    handlers.fetch(event)

    await expect(event.response).resolves.toEqual({ network: true })
    expect(fetch).toHaveBeenCalledWith(event.request)
  })

  it("serves the requested byte range from a downloaded audio file", async () => {
    const headers = new Headers({ "Content-Type": "audio/mpeg" })
    cache.match.mockResolvedValue(new Response(new Uint8Array([ 10, 20, 30, 40 ]), { headers }))
    const event = requestEvent("http://sonzra.test/server_connections/1/audio/track-1", "bytes=1-2")

    handlers.fetch(event)

    const response = await event.response
    expect(response.status).toBe(206)
    expect(response.headers.get("Content-Range")).toBe("bytes 1-2/4")
    expect(Array.from(new Uint8Array(await response.arrayBuffer()))).toEqual([ 20, 30 ])
  })

  it("does not intercept unrelated requests", () => {
    const event = requestEvent("http://sonzra.test/library/albums")

    handlers.fetch(event)

    expect(event.response).toBeUndefined()
  })

  it("retains app assets while connected and serves them from cache offline", async () => {
    const asset = { ok: true, clone: vi.fn(() => ({ cached: true })) }
    fetch.mockResolvedValueOnce(asset)
    const event = requestEvent("http://sonzra.test/icon-192.png")

    handlers.fetch(event)

    await expect(event.response).resolves.toBe(asset)
    expect(caches.open).toHaveBeenCalledWith("sonzra-offline-assets-v1")
    expect(cache.put).toHaveBeenCalledWith(event.request, expect.any(Object))

    const offlineAsset = { offline: true }
    cache.match.mockResolvedValueOnce(offlineAsset)
    fetch.mockRejectedValueOnce(new Error("Network unavailable"))
    const offlineEvent = requestEvent("http://sonzra.test/icon-192.png")

    handlers.fetch(offlineEvent)

    await expect(offlineEvent.response).resolves.toBe(offlineAsset)
  })

  it("replaces any unreachable app page with the Downloads-only offline screen", async () => {
    const offlineScreen = { offline: true }
    cache.match.mockResolvedValue(offlineScreen)
    fetch.mockRejectedValueOnce(new Error("Network unavailable"))
    const event = documentRequestEvent("http://sonzra.test/library/albums")

    handlers.fetch(event)

    await expect(event.response).resolves.toBe(offlineScreen)
  })

  function requestEvent(url, range = null) {
    return {
      request: { method: "GET", url, headers: new Headers(range ? { Range: range } : {}) },
      respondWith(response) { this.response = response }
    }
  }

  function documentRequestEvent(url) {
    const event = requestEvent(url)
    event.request.mode = "navigate"
    return event
  }
})
