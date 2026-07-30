import { Application } from "@hotwired/stimulus"
import { afterEach, beforeEach, describe, expect, it } from "vitest"
import NavigationController from "../../app/javascript/controllers/navigation_controller.js"

describe("navigation controller", () => {
  let application

  beforeEach(() => {
    document.body.innerHTML = `
      <header data-controller="navigation">
        <button data-navigation-target="toggle" data-action="navigation#toggle" aria-expanded="false"></button>
        <div data-navigation-target="menu"></div>
      </header>
    `
    application = Application.start()
    application.register("navigation", NavigationController)
  })

  afterEach(() => application.stop())

  it("opens and closes the mobile navigation menu", () => {
    const toggle = document.querySelector("[data-navigation-target='toggle']")
    const menu = document.querySelector("[data-navigation-target='menu']")

    toggle.click()
    expect(menu.classList).toContain("is-open")
    expect(toggle.getAttribute("aria-expanded")).toBe("true")

    toggle.click()
    expect(menu.classList).not.toContain("is-open")
    expect(toggle.getAttribute("aria-expanded")).toBe("false")
  })
})
