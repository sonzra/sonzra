import { Application } from "@hotwired/stimulus"
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import ServerSwitchController from "../../app/javascript/controllers/server_switch_controller.js"

describe("server switch controller", () => {
  let application
  let controller

  beforeEach(async () => {
    document.body.innerHTML = '<form data-controller="server-switch" data-server-switch-connection-id-value="2" data-server-switch-current-connection-id-value="1"></form>'
    globalThis.Turbo = { cache: { clear: vi.fn() } }
    application = Application.start()
    application.register("server-switch", ServerSwitchController)
    await new Promise((resolve) => setTimeout(resolve, 0))
    controller = application.getControllerForElementAndIdentifier(document.querySelector("form"), "server-switch")
  })

  afterEach(() => {
    application.stop()
    delete globalThis.Turbo
  })

  it("clears browser and player state before changing servers", () => {
    const player = { clearQueue: vi.fn() }
    vi.spyOn(application, "getControllerForElementAndIdentifier").mockReturnValue(player)

    controller.switch()

    expect(globalThis.Turbo.cache.clear).toHaveBeenCalledOnce()
    expect(player.clearQueue).toHaveBeenCalledOnce()
  })
})
