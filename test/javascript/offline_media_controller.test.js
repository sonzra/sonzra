import { Application } from "@hotwired/stimulus"
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import OfflineMediaController from "../../app/javascript/controllers/offline_media_controller.js"

describe("offline media controller", () => {
  let application
  let controller
  let mockStore

  beforeEach(async () => {
    mockStore = {
      catalog: vi.fn(() => []),
      warmOfflineShell: vi.fn(),
      requestPersistentStorage: vi.fn(),
      clear: vi.fn()
    }

    document.body.innerHTML = `
      <div data-controller="offline-media" data-offline-media-scope-value="user-1"></div>
    `
    application = Application.start()
    application.register("offline-media", OfflineMediaController)

    // Override store() prototype to return mockStore
    vi.spyOn(OfflineMediaController.prototype, "store").mockImplementation(() => mockStore)

    await Promise.resolve()
    controller = application.getControllerForElementAndIdentifier(document.querySelector("[data-controller='offline-media']"), "offline-media")
  })

  afterEach(() => {
    application?.stop()
    vi.restoreAllMocks()
  })

  it("warms the offline shell on connect even when download catalog is empty", () => {
    expect(mockStore.catalog()).toHaveLength(0)
    expect(mockStore.warmOfflineShell).toHaveBeenCalled()
    expect(mockStore.requestPersistentStorage).toHaveBeenCalled()
  })
})
