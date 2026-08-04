import { Application } from "@hotwired/stimulus"
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import QuickConnectController from "../../app/javascript/controllers/quick_connect_controller.js"

describe("quick connect controller", () => {
  let application

  beforeEach(() => {
    document.body.innerHTML = '<section data-controller="quick-connect" data-quick-connect-status-url-value="/server_connections/quick_connect_status"><p data-quick-connect-target="message">Waiting for approval…</p></section>'
    vi.stubGlobal("fetch", vi.fn(() => Promise.resolve({ json: () => Promise.resolve({ status: "pending" }) })))
    application = Application.start()
    application.register("quick-connect", QuickConnectController)
  })

  afterEach(() => {
    application.stop()
    vi.restoreAllMocks()
    vi.unstubAllGlobals()
  })

  it("polls the connection status while it is awaiting approval", async () => {
    const controller = application.getControllerForElementAndIdentifier(document.querySelector("[data-controller]"), "quick-connect")

    await controller.poll()

    expect(fetch).toHaveBeenCalledWith("/server_connections/quick_connect_status", { headers: { Accept: "application/json" } })
    expect(document.querySelector("[data-quick-connect-target='message']").textContent).toBe("Waiting for approval…")
  })
})
