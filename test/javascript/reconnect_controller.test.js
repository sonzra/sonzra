import { Application } from "@hotwired/stimulus"
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import ReconnectController from "../../app/javascript/controllers/reconnect_controller.js"

describe("reconnect controller", () => {
  let application
  let controller

  beforeEach(async () => {
    document.body.innerHTML = `
      <div id="connection-alert-1" class="connection-alert" data-controller="reconnect" data-reconnect-dialog-id-value="reconnect-dialog">
        <button type="button" class="connection-alert__dismiss" data-action="reconnect#dismiss">Dismiss</button>
      </div>
      <dialog id="reconnect-dialog">
        <button type="button" class="close-btn" data-action="reconnect#close">Close</button>
      </dialog>
    `
    const dialog = document.getElementById("reconnect-dialog")
    dialog.showModal = vi.fn()
    dialog.close = vi.fn()

    application = Application.start()
    application.register("reconnect", ReconnectController)
    await new Promise((resolve) => setTimeout(resolve, 0))
    controller = application.getControllerForElementAndIdentifier(document.getElementById("connection-alert-1"), "reconnect")
  })

  afterEach(() => {
    application.stop()
  })

  it("opens the reconnect dialog when open is called", () => {
    const dialog = document.getElementById("reconnect-dialog")
    controller.open()
    expect(dialog.showModal).toHaveBeenCalledOnce()
  })

  it("closes the reconnect dialog when close is called", () => {
    const dialog = document.getElementById("reconnect-dialog")
    controller.close({ preventDefault: vi.fn() })
    expect(dialog.close).toHaveBeenCalledOnce()
  })

  it("removes the alert element when dismissed", () => {
    const alert = document.getElementById("connection-alert-1")
    controller.dismiss({ preventDefault: vi.fn() })
    expect(document.getElementById("connection-alert-1")).toBeNull()
  })

  it("opens the dialog when turbo:frame-load is dispatched on a dialog controller", async () => {
    document.body.innerHTML = `
      <dialog id="reconnect-dialog" data-controller="reconnect">
        <turbo-frame id="reconnect_modal"></turbo-frame>
      </dialog>
    `
    const dialog = document.getElementById("reconnect-dialog")
    dialog.showModal = vi.fn()
    dialog.close = vi.fn()

    application.stop()
    application = Application.start()
    application.register("reconnect", ReconnectController)
    await new Promise((resolve) => setTimeout(resolve, 0))

    dialog.dispatchEvent(new CustomEvent("turbo:frame-load", { bubbles: true }))
    expect(dialog.showModal).toHaveBeenCalledOnce()
  })

  it("closes the dialog when clicking directly on the backdrop", async () => {
    document.body.innerHTML = `
      <dialog id="reconnect-dialog" data-controller="reconnect">
        <div class="content">Modal content</div>
      </dialog>
    `
    const dialog = document.getElementById("reconnect-dialog")
    dialog.showModal = vi.fn()
    dialog.close = vi.fn()

    application.stop()
    application = Application.start()
    application.register("reconnect", ReconnectController)
    await new Promise((resolve) => setTimeout(resolve, 0))

    dialog.dispatchEvent(new MouseEvent("click", { bubbles: true }))
    expect(dialog.close).toHaveBeenCalledOnce()
  })
})
