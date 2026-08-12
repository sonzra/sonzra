import { Application } from "@hotwired/stimulus"
import { afterEach, beforeEach, describe, expect, it } from "vitest"
import ProfileMenuController from "../../app/javascript/controllers/profile_menu_controller.js"

describe("profile menu controller", () => {
  let application

  beforeEach(async () => {
    document.body.innerHTML = '<div data-controller="profile-menu"><button data-profile-menu-target="toggle" data-action="profile-menu#toggle" aria-expanded="false"></button><div data-profile-menu-target="menu" data-action="click->profile-menu#closeOnAction" hidden><a href="/settings">Settings</a></div></div>'
    application = Application.start()
    application.register("profile-menu", ProfileMenuController)
    await Promise.resolve()
  })

  afterEach(() => application?.stop())

  it("opens the account actions from the profile control", () => {
    const toggle = document.querySelector("button")
    const menu = document.querySelector("div div")
    toggle.click()
    expect(toggle.getAttribute("aria-expanded")).toBe("true")
    expect(menu.hidden).toBe(false)
  })

  it("closes after a profile action is selected", () => {
    document.querySelector("button").click()
    document.querySelector("a").click()

    expect(document.querySelector("div div").hidden).toBe(true)
  })
})
