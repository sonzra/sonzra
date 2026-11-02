const DEFAULT_DB_NAME = "sonzra_offline"
const DEFAULT_STORE_NAME = "playback_events"
const DB_VERSION = 1

export class OfflineOutbox {
  constructor({
    dbName = DEFAULT_DB_NAME,
    storeName = DEFAULT_STORE_NAME,
    indexedDB = globalThis.indexedDB
  } = {}) {
    this.dbName = dbName
    this.storeName = storeName
    this.indexedDB = indexedDB
    this._dbPromise = null
  }

  supported() {
    return Boolean(this.indexedDB?.open)
  }

  async enqueue(event) {
    if (!this.supported()) return null

    const db = await this._getDb()
    const occurredAt = event.occurredAt || new Date().toISOString()
    const record = { ...event, occurredAt }

    return new Promise((resolve, reject) => {
      const transaction = db.transaction([ this.storeName ], "readwrite")
      const store = transaction.objectStore(this.storeName)

      transaction.onerror = () => reject(transaction.error)

      if (record.event === "progress" && record.itemId) {
        const index = store.index("itemId")
        const request = index.getAll(record.itemId)

        request.onsuccess = () => {
          const matches = request.result || []
          const existingProgress = matches.find((m) => m.event === "progress")

          if (existingProgress) {
            const updated = { ...record, id: existingProgress.id }
            const putReq = store.put(updated)
            putReq.onsuccess = () => resolve(existingProgress.id)
            putReq.onerror = () => reject(putReq.error)
          } else {
            const addReq = store.add(record)
            addReq.onsuccess = () => resolve(addReq.result)
            addReq.onerror = () => reject(addReq.error)
          }
        }
        request.onerror = () => reject(request.error)
      } else {
        const addReq = store.add(record)
        addReq.onsuccess = () => resolve(addReq.result)
        addReq.onerror = () => reject(addReq.error)
      }
    })
  }

  async pendingEvents() {
    if (!this.supported()) return []

    const db = await this._getDb()

    return new Promise((resolve, reject) => {
      const transaction = db.transaction([ this.storeName ], "readonly")
      const store = transaction.objectStore(this.storeName)
      const request = store.getAll()

      request.onsuccess = () => {
        const events = request.result || []
        events.sort((a, b) => {
          const timeA = a.occurredAt ? new Date(a.occurredAt).getTime() : 0
          const timeB = b.occurredAt ? new Date(b.occurredAt).getTime() : 0
          return timeA - timeB
        })
        resolve(events)
      }

      request.onerror = () => reject(request.error)
    })
  }

  async clearEvents(ids) {
    if (!this.supported() || !ids || ids.length === 0) return

    const db = await this._getDb()

    return new Promise((resolve, reject) => {
      const transaction = db.transaction([ this.storeName ], "readwrite")
      const store = transaction.objectStore(this.storeName)

      for (const id of ids) {
        store.delete(id)
      }

      transaction.oncomplete = () => resolve()
      transaction.onerror = () => reject(transaction.error)
    })
  }

  async count() {
    if (!this.supported()) return 0

    const db = await this._getDb()

    return new Promise((resolve, reject) => {
      const transaction = db.transaction([ this.storeName ], "readonly")
      const store = transaction.objectStore(this.storeName)
      const request = store.count()

      request.onsuccess = () => resolve(request.result)
      request.onerror = () => reject(request.error)
    })
  }

  async close() {
    if (this._dbPromise) {
      const db = await this._dbPromise
      db.close()
      this._dbPromise = null
    }
  }

  async _getDb() {
    if (this._dbPromise) return this._dbPromise
    if (!this.supported()) {
      throw new Error("IndexedDB is not supported in this environment.")
    }

    this._dbPromise = new Promise((resolve, reject) => {
      const request = this.indexedDB.open(this.dbName, DB_VERSION)

      request.onupgradeneeded = (e) => {
        const db = e.target.result
        if (!db.objectStoreNames.contains(this.storeName)) {
          const store = db.createObjectStore(this.storeName, { keyPath: "id", autoIncrement: true })
          store.createIndex("itemId", "itemId", { unique: false })
          store.createIndex("occurredAt", "occurredAt", { unique: false })
        }
      }

      request.onsuccess = (e) => resolve(e.target.result)
      request.onerror = () => {
        this._dbPromise = null
        reject(request.error)
      }
      request.onblocked = () => {
        this._dbPromise = null
        reject(new Error("IndexedDB open blocked."))
      }
    })

    return this._dbPromise
  }
}
