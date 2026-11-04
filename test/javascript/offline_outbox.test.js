import "fake-indexeddb/auto"
import { afterEach, beforeEach, describe, expect, it } from "vitest"
import { OfflineOutbox } from "../../app/javascript/offline_outbox.js"

describe("OfflineOutbox", () => {
  let outbox
  const testDbName = "sonzra_offline_test"

  beforeEach(() => {
    outbox = new OfflineOutbox({ dbName: testDbName })
  })

  afterEach(async () => {
    if (outbox) {
      await outbox.close()
    }
    await new Promise((resolve) => {
      const request = indexedDB.deleteDatabase(testDbName)
      request.onsuccess = () => resolve()
      request.onerror = () => resolve()
      request.onblocked = () => resolve()
    })
  })

  it("enqueues and retrieves playback start and stopped events with timestamps", async () => {
    const startEvent = {
      event: "started",
      serverConnectionId: "conn-1",
      itemId: "track-123",
      reportingUrl: "/playback/start",
      positionTicks: 0,
      durationTicks: 1800000000,
      occurredAt: "2026-11-02T14:30:00.000Z",
      resumable: false,
      paused: false
    }

    const stoppedEvent = {
      event: "stopped",
      serverConnectionId: "conn-1",
      itemId: "track-123",
      reportingUrl: "/playback/stop",
      positionTicks: 1800000000,
      durationTicks: 1800000000,
      occurredAt: "2026-11-02T14:33:00.000Z",
      resumable: false,
      paused: false
    }

    const id1 = await outbox.enqueue(startEvent)
    const id2 = await outbox.enqueue(stoppedEvent)

    expect(id1).toBeDefined()
    expect(id2).toBeDefined()
    expect(await outbox.count()).toBe(2)

    const pending = await outbox.pendingEvents()
    expect(pending).toHaveLength(2)
    expect(pending[0].event).toBe("started")
    expect(pending[0].occurredAt).toBe("2026-11-02T14:30:00.000Z")
    expect(pending[1].event).toBe("stopped")
    expect(pending[1].occurredAt).toBe("2026-11-02T14:33:00.000Z")
  })

  it("throttles progress ticks by maintaining only the latest position tick per active track item", async () => {
    await outbox.enqueue({
      event: "started",
      serverConnectionId: "conn-1",
      itemId: "track-100",
      positionTicks: 0,
      occurredAt: "2026-11-02T14:00:00.000Z"
    })

    await outbox.enqueue({
      event: "progress",
      serverConnectionId: "conn-1",
      itemId: "track-100",
      positionTicks: 100000,
      occurredAt: "2026-11-02T14:00:10.000Z"
    })

    await outbox.enqueue({
      event: "progress",
      serverConnectionId: "conn-1",
      itemId: "track-100",
      positionTicks: 200000,
      occurredAt: "2026-11-02T14:00:20.000Z"
    })

    await outbox.enqueue({
      event: "progress",
      serverConnectionId: "conn-1",
      itemId: "track-100",
      positionTicks: 300000,
      occurredAt: "2026-11-02T14:00:30.000Z"
    })

    // Started event + 1 throttled progress event = 2 total events
    expect(await outbox.count()).toBe(2)

    const pending = await outbox.pendingEvents()
    expect(pending).toHaveLength(2)
    expect(pending[0].event).toBe("started")
    expect(pending[1].event).toBe("progress")
    expect(pending[1].positionTicks).toBe(300000)
    expect(pending[1].occurredAt).toBe("2026-11-02T14:00:30.000Z")
  })

  it("throttles progress independently across different track items", async () => {
    await outbox.enqueue({
      event: "progress",
      serverConnectionId: "conn-1",
      itemId: "track-A",
      positionTicks: 1000,
      occurredAt: "2026-11-02T14:00:00.000Z"
    })

    await outbox.enqueue({
      event: "progress",
      serverConnectionId: "conn-1",
      itemId: "track-B",
      positionTicks: 5000,
      occurredAt: "2026-11-02T14:00:05.000Z"
    })

    await outbox.enqueue({
      event: "progress",
      serverConnectionId: "conn-1",
      itemId: "track-A",
      positionTicks: 2000,
      occurredAt: "2026-11-02T14:00:10.000Z"
    })

    expect(await outbox.count()).toBe(2)
    const pending = await outbox.pendingEvents()
    const itemA = pending.find((e) => e.itemId === "track-A")
    const itemB = pending.find((e) => e.itemId === "track-B")
    expect(itemA.positionTicks).toBe(2000)
    expect(itemB.positionTicks).toBe(5000)
  })

  it("atomically clears only specified event IDs while preserving unconfirmed events", async () => {
    const id1 = await outbox.enqueue({
      event: "started",
      serverConnectionId: "conn-1",
      itemId: "track-1",
      occurredAt: "2026-11-02T14:00:00.000Z"
    })

    const id2 = await outbox.enqueue({
      event: "stopped",
      serverConnectionId: "conn-1",
      itemId: "track-1",
      occurredAt: "2026-11-02T14:03:00.000Z"
    })

    const id3 = await outbox.enqueue({
      event: "started",
      serverConnectionId: "conn-1",
      itemId: "track-2",
      occurredAt: "2026-11-02T14:04:00.000Z"
    })

    expect(await outbox.count()).toBe(3)

    // Clear only id1 and id2
    await outbox.clearEvents([ id1, id2 ])

    expect(await outbox.count()).toBe(1)
    const remaining = await outbox.pendingEvents()
    expect(remaining).toHaveLength(1)
    expect(remaining[0].id).toBe(id3)
    expect(remaining[0].itemId).toBe("track-2")
  })

  it("sorts pending events in chronological order by occurredAt", async () => {
    await outbox.enqueue({
      event: "started",
      serverConnectionId: "conn-1",
      itemId: "track-2",
      occurredAt: "2026-11-02T15:00:00.000Z"
    })

    await outbox.enqueue({
      event: "started",
      serverConnectionId: "conn-1",
      itemId: "track-1",
      occurredAt: "2026-11-02T14:00:00.000Z"
    })

    const pending = await outbox.pendingEvents()
    expect(pending[0].occurredAt).toBe("2026-11-02T14:00:00.000Z")
    expect(pending[1].occurredAt).toBe("2026-11-02T15:00:00.000Z")
  })

  it("resets _dbPromise on open error to allow subsequent connection retry", async () => {
    let failOpen = true
    const mockIndexedDB = {
      open: () => {
        const req = {}
        setTimeout(() => {
          if (failOpen) {
            req.error = new Error("Mock DB failure")
            req.onerror()
          } else {
            req.result = {
              transaction: () => ({
                objectStore: () => ({
                  count: () => {
                    const r = { result: 0 }
                    setTimeout(() => r.onsuccess(), 0)
                    return r
                  }
                })
              })
            }
            req.onsuccess({ target: req })
          }
        }, 0)
        return req
      }
    }

    const testOutbox = new OfflineOutbox({ indexedDB: mockIndexedDB })
    await expect(testOutbox.count()).rejects.toThrow("Mock DB failure")

    failOpen = false
    await expect(testOutbox.count()).resolves.toBe(0)
  })
})
