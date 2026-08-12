import { Application } from "@hotwired/stimulus"
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import OfflineConnectionController from "../../app/javascript/controllers/offline_connection_controller.js"

describe("offline connection controller", () => {
  let application
  let controller
  let fetchMock

  beforeEach(async () => {
    vi.useFakeTimers()
    fetchMock = vi.fn(async () => { throw new Error("Offline") })
    vi.stubGlobal("fetch", fetchMock)
    document.body.innerHTML = `
      <main data-controller="offline-connection">
        <span data-offline-connection-target="status"></span>
        <button data-offline-connection-target="retry"></button>
        <a href="/library/albums" data-offline-connection-target="navigationLink"></a>
      </main>
    `
    application = Application.start()
    application.register("offline-connection", OfflineConnectionController)
    await Promise.resolve()
    controller = application.getControllerForElementAndIdentifier(document.querySelector("[data-controller='offline-connection']"), "offline-connection")
  })

  afterEach(() => {
    application?.stop()
    vi.useRealTimers()
    vi.unstubAllGlobals()
    vi.restoreAllMocks()
  })

  it("keeps server navigation disabled while Sonzra is unreachable", async () => {
    await Promise.resolve()
    const event = { preventDefault: vi.fn() }

    controller.preventNavigation(event)

    expect(event.preventDefault).toHaveBeenCalled()
    expect(document.querySelector("[data-offline-connection-target='status']").textContent).toBe("Offline — downloads only")
  })

  it("shows a green reconnection state when the health endpoint succeeds", async () => {
    fetchMock.mockResolvedValueOnce({ ok: true })

    await controller.check()

    const status = document.querySelector("[data-offline-connection-target='status']")
    expect(fetchMock).toHaveBeenLastCalledWith("/up", { cache: "no-store" })
    expect(status.dataset.state).toBe("online")
    expect(status.textContent).toBe("Back online")
    expect(document.querySelector("[data-offline-connection-target='retry']").hidden).toBe(true)
  })
})
