import { Application } from "@hotwired/stimulus"
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import LibrarySearchController from "../../app/javascript/controllers/library_search_controller.js"

describe("library search controller", () => {
  let application

  beforeEach(() => {
    document.body.innerHTML = '<div data-controller="library-search"><button data-action="library-search#open"></button><dialog data-library-search-target="dialog"><input data-library-search-target="input"></dialog></div>'
    HTMLDialogElement.prototype.showModal = vi.fn(function showModal() { this.setAttribute("open", "") })
    HTMLDialogElement.prototype.close = vi.fn(function close() { this.removeAttribute("open") })
    vi.stubGlobal("requestAnimationFrame", (callback) => callback())
    application = Application.start()
    application.register("library-search", LibrarySearchController)
  })

  afterEach(() => {
    application.stop()
    vi.restoreAllMocks()
    vi.unstubAllGlobals()
  })

  it("opens and closes the contextual search dialog", () => {
    const trigger = document.querySelector("button")
    const dialog = document.querySelector("dialog")

    trigger.click()
    expect(dialog.hasAttribute("open")).toBe(true)

    application.getControllerForElementAndIdentifier(document.querySelector("[data-controller]"), "library-search").close()
    expect(dialog.hasAttribute("open")).toBe(false)
  })
})
