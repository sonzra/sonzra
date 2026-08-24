import { Application } from "@hotwired/stimulus"
import { afterEach, beforeEach, describe, expect, it } from "vitest"
import TooltipController from "../../app/javascript/controllers/tooltip_controller.js"

describe("tooltip controller", () => {
  let application

  beforeEach(() => {
    document.body.innerHTML = '<main data-controller="tooltip"><button aria-label="Play track"></button></main>'
    application = Application.start()
    application.register("tooltip", TooltipController)
  })

  afterEach(() => application.stop())

  it("shows a styled tooltip instead of a native browser title", async () => {
    const button = document.querySelector("button")
    button.dispatchEvent(new MouseEvent("pointerover", { bubbles: true }))
    await Promise.resolve()

    expect(button.title).toBe("")
    expect(document.querySelector(".sonzra-tooltip").textContent).toBe("Play track")
    expect(document.querySelector(".sonzra-tooltip").hidden).toBe(false)
  })
})
