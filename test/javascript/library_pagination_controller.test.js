import { Application } from "@hotwired/stimulus"
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import LibraryPaginationController from "../../app/javascript/controllers/library_pagination_controller.js"

describe("library pagination controller", () => {
  let application
  let controller
  let observeMock

  beforeEach(async () => {
    observeMock = vi.fn()
    vi.stubGlobal("IntersectionObserver", class {
      constructor(callback, options) {
        this.callback = callback
        this.options = options
      }
      observe = observeMock
      disconnect = vi.fn()
    })

    document.body.innerHTML = `
      <div data-controller="library-pagination"
           data-library-pagination-has-more-value="true"
           data-library-pagination-page-value="1"
           data-library-pagination-letter-value=""
           data-library-pagination-url-value="/library/artists">
        <div data-library-pagination-target="grid" id="library-grid">
          <article>Artist 1</article>
        </div>
        <div data-library-pagination-target="sentinel"></div>
        <div id="library-scroll-state"
             data-library-pagination-target="state"
             data-has-more="true"
             data-page="1"
             data-letter=""
             hidden></div>
        <nav data-library-pagination-target="alphabet">
          <button type="button" data-action="library-pagination#jumpToLetter" data-library-pagination-letter-param="B">B</button>
        </nav>
      </div>
    `
    application = Application.start()
    application.register("library-pagination", LibraryPaginationController)
    await Promise.resolve()
    controller = application.getControllerForElementAndIdentifier(
      document.querySelector("[data-controller='library-pagination']"),
      "library-pagination"
    )
  })

  afterEach(() => {
    application?.stop()
    vi.unstubAllGlobals()
    vi.restoreAllMocks()
  })

  it("observes the sentinel on connect", () => {
    expect(observeMock).toHaveBeenCalled()
  })

  it("fetches the next page with turbo stream header when sentinel intersects", async () => {
    global.fetch = vi.fn(() => Promise.resolve({
      ok: true,
      text: () => Promise.resolve('<turbo-stream action="append" target="library-grid"><template><article>Artist 2</article></template></turbo-stream>')
    }))

    await controller.onSentinelVisible([{ isIntersecting: true }])

    expect(global.fetch).toHaveBeenCalledWith(
      expect.stringContaining("/library/artists?page=2"),
      expect.objectContaining({ headers: { Accept: "text/vnd.turbo-stream.html" } })
    )
  })

  it("calls Turbo.visit when jumpToLetter is triggered", () => {
    const turboVisitMock = vi.fn()
    vi.stubGlobal("Turbo", { visit: turboVisitMock })

    const button = document.querySelector("button[data-library-pagination-letter-param='B']")
    button.click()

    expect(turboVisitMock).toHaveBeenCalledWith(expect.stringContaining("/library/artists?letter=B"))
  })

  it("does not fetch next page when hasMore is false", async () => {
    controller.hasMoreValue = false
    global.fetch = vi.fn()

    await controller.onSentinelVisible([{ isIntersecting: true }])

    expect(global.fetch).not.toHaveBeenCalled()
  })
})
