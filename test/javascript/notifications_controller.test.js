import { Application } from "@hotwired/stimulus"
import { afterEach, beforeEach, describe, expect, it } from "vitest"
import NotificationsController from "../../app/javascript/controllers/notifications_controller.js"

describe("notifications controller", () => {
  let application

  beforeEach(async () => {
    document.body.innerHTML = `
      <div data-controller="notifications">
        <button data-notifications-target="toggle" data-action="notifications#toggle" aria-expanded="false">
          Bell
        </button>
        <div data-notifications-target="drawer" hidden>
          <button data-action="notifications#close">Close</button>
          <ul data-notifications-target="list">
            <li>Item 1</li>
          </ul>
        </div>
      </div>
      <div id="outside">Outside</div>
    `
    application = Application.start()
    application.register("notifications", NotificationsController)
    await Promise.resolve()
  })

  afterEach(() => application?.stop())

  it("opens and closes the notification drawer on toggle", () => {
    const toggle = document.querySelector("button[data-notifications-target='toggle']")
    const drawer = document.querySelector("div[data-notifications-target='drawer']")

    expect(drawer.hidden).toBe(true)
    expect(toggle.getAttribute("aria-expanded")).toBe("false")

    toggle.click()
    expect(drawer.hidden).toBe(false)
    expect(toggle.getAttribute("aria-expanded")).toBe("true")

    toggle.click()
    expect(drawer.hidden).toBe(true)
    expect(toggle.getAttribute("aria-expanded")).toBe("false")
  })

  it("closes when clicking outside the controller element", () => {
    const toggle = document.querySelector("button[data-notifications-target='toggle']")
    const drawer = document.querySelector("div[data-notifications-target='drawer']")
    const outside = document.getElementById("outside")

    toggle.click()
    expect(drawer.hidden).toBe(false)

    outside.click()
    expect(drawer.hidden).toBe(true)
  })

  it("closes on Escape key press", () => {
    const toggle = document.querySelector("button[data-notifications-target='toggle']")
    const drawer = document.querySelector("div[data-notifications-target='drawer']")

    toggle.click()
    expect(drawer.hidden).toBe(false)

    document.dispatchEvent(new KeyboardEvent("keydown", { key: "Escape" }))
    expect(drawer.hidden).toBe(true)
  })

  it("closes on turbo:before-visit event", () => {
    const toggle = document.querySelector("button[data-notifications-target='toggle']")
    const drawer = document.querySelector("div[data-notifications-target='drawer']")

    toggle.click()
    expect(drawer.hidden).toBe(false)

    document.dispatchEvent(new CustomEvent("turbo:before-visit"))
    expect(drawer.hidden).toBe(true)
  })
})
