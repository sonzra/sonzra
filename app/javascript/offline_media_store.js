const CACHE_NAME = "sonzra-offline-media-v1"
const OFFLINE_SHELL_CACHE = "sonzra-offline-shell-v2"
const OFFLINE_ASSET_CACHE = "sonzra-offline-assets-v1"
const OFFLINE_SHELL_PATH = "/offline_shell"
const CATALOG_KEY_PREFIX = "sonzra:offline-media:"
const ACTIVE_SCOPE_KEY = "sonzra:offline-media:active-scope"
const COLLECTION_CATALOG_KEY_PREFIX = "sonzra:offline-collections:"

export class OfflineMediaStore {
  constructor({ scope, cacheStorage = globalThis.caches, storage = globalThis.localStorage, fetcher = (...arguments_) => globalThis.fetch(...arguments_) } = {}) {
    this.scope = scope || "anonymous"
    this.cacheStorage = cacheStorage
    this.storage = storage
    this.fetcher = fetcher
    this.storage?.setItem(ACTIVE_SCOPE_KEY, this.scope)
  }

  supported() {
    return Boolean(this.cacheStorage?.open && this.fetcher && this.storage)
  }

  async downloaded(source) {
    if (!source || !this.supported()) return false

    if (!this.catalog().some((item) => item.source === source)) return false

    try {
      const cache = await this.cacheStorage.open(CACHE_NAME)
      return Boolean(await cache.match(source))
    } catch (_) {
      return false
    }
  }

  async download(track, { signal } = {}) {
    if (!track?.source) throw new OfflineMediaStoreError("This item cannot be downloaded for offline playback.")
    if (!this.supported()) throw new OfflineMediaStoreError("Offline downloads are not supported by this browser.")
    if (signal?.aborted) throw new DOMException("Offline download cancelled", "AbortError")

    const response = await this.fetcher(track.source, { credentials: "same-origin", signal })
    if (!response.ok) throw new OfflineMediaStoreError("Sonzra couldn’t download this item. Try again while connected.")

    try {
      const cache = await this.cacheStorage.open(CACHE_NAME)
      await cache.put(track.source, response.clone())
      await this.cacheArtwork(cache, track.artwork)
      this.save({ ...track, downloadedAt: new Date().toISOString() })
    } catch (_) {
      throw new OfflineMediaStoreError("Your browser couldn’t save this download. Check available device storage and try again.")
    }
  }

  async downloadAll(tracks, onProgress = () => {}, { signal } = {}) {
    let downloadedCount = 0

    for (const [ index, track ] of tracks.entries()) {
      if (!await this.downloaded(track.source)) {
        await this.download(track, { signal })
        downloadedCount += 1
      }
      onProgress(index + 1, tracks.length)
    }

    return downloadedCount
  }

  async warmOfflineShell() {
    if (!this.supported()) return

    try {
      const response = await this.fetcher(OFFLINE_SHELL_PATH, { credentials: "same-origin" })
      if (!response.ok) return

      const cache = await this.cacheStorage.open(OFFLINE_SHELL_CACHE)
      await cache.put(OFFLINE_SHELL_PATH, response.clone())
      await this.warmOfflineAssets()
    } catch (_) {
      // Offline playback remains available even when the shell cannot be refreshed.
    }
  }

  async warmOfflineAssets() {
    const resources = globalThis.performance?.getEntriesByType?.("resource") || []
    const urls = [ ...new Set(resources.map((resource) => resource.name).filter((url) => this.offlineAsset(url))) ]
    if (urls.length === 0) return

    try {
      const cache = await this.cacheStorage.open(OFFLINE_ASSET_CACHE)
      await Promise.all(urls.map(async (url) => {
        const response = await this.fetcher(url, { credentials: "same-origin" })
        if (response.ok) await cache.put(url, response)
      }))
    } catch (_) {
      // Individual app assets are best-effort; media downloads remain usable.
    }
  }

  async requestPersistentStorage() {
    if (!globalThis.navigator?.storage?.persist) return false

    try {
      return await globalThis.navigator.storage.persist()
    } catch (_) {
      return false
    }
  }

  async storageEstimate() {
    if (!globalThis.navigator?.storage?.estimate) return null

    try {
      return await globalThis.navigator.storage.estimate()
    } catch (_) {
      return null
    }
  }

  async clear() {
    if (this.cacheStorage?.delete) await this.cacheStorage.delete(CACHE_NAME)
    if (this.cacheStorage?.delete) await this.cacheStorage.delete(OFFLINE_SHELL_CACHE)
    this.storage?.removeItem(this.catalogKey())
    this.storage?.removeItem(this.collectionCatalogKey())
    if (this.storage?.getItem(ACTIVE_SCOPE_KEY) === this.scope) this.storage.removeItem(ACTIVE_SCOPE_KEY)
  }

  async remove(source) {
    return this.removeAll([ source ])
  }

  async removeAll(sources) {
    if (!this.supported()) return

    const sourceSet = new Set(sources.filter(Boolean))
    if (sourceSet.size === 0) return

    const catalog = this.catalog()
    const removed = catalog.filter((item) => sourceSet.has(item.source))
    const remaining = catalog.filter((item) => !sourceSet.has(item.source))
    const cache = await this.cacheStorage.open(CACHE_NAME)
    await Promise.all(removed.map((item) => cache.delete(item.source)))
    await Promise.all([ ...new Set(removed.map((item) => item.artwork).filter(Boolean)) ].filter((artwork) => !remaining.some((item) => item.artwork === artwork)).map((artwork) => cache.delete(artwork)))

    if (remaining.length === 0) {
      this.storage.removeItem(this.catalogKey())
    } else {
      this.storage.setItem(this.catalogKey(), JSON.stringify(remaining))
    }

    this.saveCollections(this.collections().map((collection) => ({ ...collection, sources: collection.sources.filter((source) => !sourceSet.has(source)) })).filter((collection) => collection.sources.length > 0))
  }

  async removeByArtist(artist) {
    if (!artist) return

    await this.removeAll(this.catalog().filter((track) => track.artist === artist || track.albumArtist === artist).map((track) => track.source))
  }

  catalog() {
    try {
      return JSON.parse(this.storage?.getItem(this.catalogKey()) || "[]")
    } catch (_) {
      return []
    }
  }

  collectionDownloaded(queueUrl) {
    return Boolean(queueUrl && this.collections().some((collection) => collection.queueUrl === queueUrl))
  }

  saveCollection(queueUrl, tracks, { title = null, artist = null, artwork = null } = {}) {
    if (!queueUrl || tracks.length === 0) return

    const sources = tracks.map((track) => track.source).filter(Boolean)
    if (sources.length === 0) return

    const collections = this.collections().filter((collection) => collection.queueUrl !== queueUrl)
    collections.push({ queueUrl, sources, title, artist, artwork, downloadedAt: new Date().toISOString() })
    this.saveCollections(collections)
  }

  collections() {
    try {
      return JSON.parse(this.storage?.getItem(this.collectionCatalogKey()) || "[]")
    } catch (_) {
      return []
    }
  }

  async cacheArtwork(cache, artwork) {
    if (!artwork || !this.fetcher) return

    try {
      const response = await this.fetcher(artwork, { credentials: "same-origin" })
      if (response.ok) await cache.put(artwork, response)
    } catch (_) {
      // Artwork is optional; a downloaded track remains playable without it.
    }
  }

  save(track) {
    const catalog = this.catalog().filter((item) => item.source !== track.source)
    catalog.push(track)
    this.storage.setItem(this.catalogKey(), JSON.stringify(catalog))
  }

  catalogKey() {
    return `${CATALOG_KEY_PREFIX}${this.scope}`
  }

  offlineAsset(url) {
    try {
      const parsed = new URL(url, globalThis.location?.origin)
      return parsed.origin === globalThis.location?.origin && (/^\/assets\//.test(parsed.pathname) || /^\/brand\//.test(parsed.pathname) || parsed.pathname === "/manifest.json" || /^\/(?:icon|favicon|apple-touch-icon)[\w-]*\.(?:png|svg|ico)$/.test(parsed.pathname))
    } catch (_) {
      return false
    }
  }

  saveCollections(collections) {
    if (collections.length === 0) {
      this.storage.removeItem(this.collectionCatalogKey())
    } else {
      this.storage.setItem(this.collectionCatalogKey(), JSON.stringify(collections))
    }
  }

  collectionCatalogKey() {
    return `${COLLECTION_CATALOG_KEY_PREFIX}${this.scope}`
  }
}

export class OfflineMediaStoreError extends Error {}
