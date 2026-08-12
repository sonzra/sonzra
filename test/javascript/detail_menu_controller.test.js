import { Application } from "@hotwired/stimulus"
import { afterEach, beforeEach, describe, expect, it } from "vitest"
import DetailMenuController from "../../app/javascript/controllers/detail_menu_controller.js"

describe("detail menu controller", () => {
  let application

  beforeEach(async () => {
    document.body.innerHTML = '<div data-controller="detail-menu"><button data-detail-menu-target="toggle" data-action="detail-menu#toggle" aria-expanded="false"></button><div data-detail-menu-target="menu" hidden></div></div>'
    application = Application.start()
    application.register("detail-menu", DetailMenuController)
    await Promise.resolve()
  })

  afterEach(() => application?.stop())

  it("toggles the album download menu", () => {
    const toggle = document.querySelector("button")
    const menu = document.querySelector("div div")

    toggle.click()

    expect(toggle.getAttribute("aria-expanded")).toBe("true")
    expect(menu.hidden).toBe(false)
  })
})
