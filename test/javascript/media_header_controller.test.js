import { Application } from "@hotwired/stimulus"
import { afterEach, beforeEach, describe, expect, it } from "vitest"
import MediaHeaderController from "../../app/javascript/controllers/media_header_controller.js"

describe("media header controller", () => {
  let application
  let artworkBottom

  beforeEach(async () => {
    artworkBottom = 320
    document.body.innerHTML = `
      <div data-controller="media-header">
        <header data-media-header-target="bar"><img data-media-header-target="thumbnail" alt=""></header>
        <div data-media-header-target="artwork"><img src="/cover.jpg" alt=""></div>
      </div>
    `
    document.querySelector("[data-media-header-target='bar']").getBoundingClientRect = () => ({ height: 65 })
    document.querySelector("[data-media-header-target='artwork']").getBoundingClientRect = () => ({ bottom: artworkBottom })
    application = Application.start()
    application.register("media-header", MediaHeaderController)
    await Promise.resolve()
  })

  afterEach(() => application.stop())

  it("shows the cover thumbnail only after the main artwork clears the header", () => {
    const header = document.querySelector("[data-media-header-target='bar']")

    expect(header.classList).not.toContain("is-artwork-condensed")

    artworkBottom = 64
    window.dispatchEvent(new Event("scroll"))
    expect(header.classList).toContain("is-artwork-condensed")

    artworkBottom = 66
    window.dispatchEvent(new Event("scroll"))
    expect(header.classList).not.toContain("is-artwork-condensed")
  })
})
