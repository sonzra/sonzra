import { Application } from "@hotwired/stimulus"
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import ServerConnectionTestController from "../../app/javascript/controllers/server_connection_test_controller.js"

describe("server connection test controller", () => {
  let application
  let controller

  beforeEach(async () => {
    document.body.innerHTML = '<section data-controller="server-connection-test"><form action="/server_connections/1/test_connection"><button type="submit">Test</button></form></section>'
    vi.stubGlobal("fetch", vi.fn(() => Promise.resolve({ json: () => Promise.resolve({ success: true, message: "Connected as Bruno." }) })))
    application = Application.start()
    application.register("server-connection-test", ServerConnectionTestController)
    await new Promise((resolve) => setTimeout(resolve, 0))
    controller = application.getControllerForElementAndIdentifier(document.querySelector("[data-controller]"), "server-connection-test")
  })

  afterEach(() => {
    application.stop()
    vi.restoreAllMocks()
    vi.unstubAllGlobals()
  })

  it("tests a connection in the background and shows its result", async () => {
    const form = document.querySelector("form")
    controller.showFeedback = vi.fn()

    await controller.run({ preventDefault: vi.fn(), currentTarget: form })

    expect(fetch).toHaveBeenCalledWith(form.action, expect.objectContaining({ method: "POST", headers: expect.objectContaining({ Accept: "application/json" }) }))
    expect(controller.showFeedback).toHaveBeenCalledWith("Connected as Bruno.")
    expect(form.querySelector("button").disabled).toBe(false)
    expect(form.querySelector("button").textContent).toBe("Test")
  })
})
