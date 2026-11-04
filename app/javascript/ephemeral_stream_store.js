export const STREAM_CACHE_NAME = "sonzra-stream-cache-v1"
export const STREAM_CACHE_INDEX_KEY = "sonzra:stream-cache-index"
export const DEFAULT_MAX_CACHE_BYTES = 200 * 1024 * 1024
export const DEFAULT_MAX_TRACKS = 3

export class EphemeralStreamStore {
  constructor({
    cacheStorage = globalThis.caches,
    storage = globalThis.localStorage,
    maxBytes = DEFAULT_MAX_CACHE_BYTES,
    maxTracks = DEFAULT_MAX_TRACKS
  } = {}) {
    this.cacheStorage = cacheStorage
    this.storage = storage
    this.maxBytes = maxBytes
    this.maxTracks = maxTracks
  }

  supported() {
    return Boolean(this.cacheStorage?.open && this.storage)
  }

  index() {
    if (!this.storage) return []

    try {
      return JSON.parse(this.storage.getItem(STREAM_CACHE_INDEX_KEY) || "[]")
    } catch (_) {
      return []
    }
  }

  saveIndex(items) {
    if (!this.storage) return
    this.storage.setItem(STREAM_CACHE_INDEX_KEY, JSON.stringify(items))
  }

  async has(source) {
    if (!source || !this.supported()) return false
    const inIndex = this.index().some((item) => item.source === source)
    if (!inIndex) return false

    try {
      const cache = await this.cacheStorage.open(STREAM_CACHE_NAME)
      return Boolean(await cache.match(source))
    } catch (_) {
      return false
    }
  }

  async put(source, response, { size } = {}) {
    if (!source || !response || !this.supported()) return

    const estimatedSize = size || Number(response.headers?.get("Content-Length")) || 0

    await this.evictToFit(estimatedSize)

    try {
      const cache = await this.cacheStorage.open(STREAM_CACHE_NAME)
      await cache.put(source, response.clone())

      const currentIndex = this.index().filter((item) => item.source !== source)
      currentIndex.push({
        source,
        size: estimatedSize,
        accessedAt: Date.now()
      })
      this.saveIndex(currentIndex)
    } catch (_) {
      // Best-effort ephemeral caching; do not break playback if caching fails
    }
  }

  touch(source) {
    if (!source || !this.storage) return

    const items = this.index()
    const target = items.find((item) => item.source === source)
    if (target) {
      target.accessedAt = Date.now()
      this.saveIndex(items)
    }
  }

  async evict(source) {
    if (!source || !this.supported()) return

    const filtered = this.index().filter((item) => item.source !== source)
    this.saveIndex(filtered)

    try {
      const cache = await this.cacheStorage.open(STREAM_CACHE_NAME)
      await cache.delete(source)
    } catch (_) {
      // Ignore cache deletion error
    }
  }

  async evictToFit(incomingBytes = 0) {
    if (!this.supported()) return

    const items = [...this.index()].sort((a, b) => a.accessedAt - b.accessedAt)
    let currentBytes = items.reduce((total, item) => total + (item.size || 0), 0)

    while (items.length > 0 && (items.length >= this.maxTracks || currentBytes + incomingBytes > this.maxBytes)) {
      const oldest = items.shift()
      if (oldest) {
        currentBytes -= oldest.size || 0
        await this.evict(oldest.source)
      }
    }
  }

  async clear() {
    if (!this.supported()) return

    this.saveIndex([])
    try {
      await this.cacheStorage.delete(STREAM_CACHE_NAME)
    } catch (_) {
      // Ignore deletion failure
    }
  }
}
