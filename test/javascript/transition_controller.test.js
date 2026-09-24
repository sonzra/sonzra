import { Application } from "@hotwired/stimulus"
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import TransitionController from "../../app/javascript/controllers/transition_controller.js"

describe("transition controller", () => {
  let application

  beforeEach(() => {
    vi.useFakeTimers()
    document.body.innerHTML = '<div data-controller="transition"><div data-transition-target="overlay" aria-hidden="true"></div><p data-transition-target="message"></p><small data-transition-target="detail"></small></div>'
    application = Application.start()
    application.register("transition", TransitionController)
  })

  afterEach(() => {
    application.stop()
    vi.useRealTimers()
  })

  it("only shows after a real Turbo visit and dismisses after the minimum display time", () => {
    const overlay = document.querySelector("[data-transition-target='overlay']")

    document.dispatchEvent(new CustomEvent("turbo:before-visit", { detail: { url: "/library/albums" } }))
    vi.advanceTimersByTime(179)
    expect(overlay.classList.contains("is-visible")).toBe(false)

    vi.advanceTimersByTime(1)
    expect(overlay.classList.contains("is-visible")).toBe(true)
    expect(document.querySelector("[data-transition-target='message']").textContent).toBe("Opening your library")

    document.dispatchEvent(new Event("turbo:load"))
    vi.advanceTimersByTime(350)
    expect(overlay.classList.contains("is-visible")).toBe(false)
    expect(overlay.getAttribute("aria-hidden")).toBe("true")
  })

  it("uses the redesign overlay for real Turbo Frame requests but ignores prefetches", () => {
    const overlay = document.querySelector("[data-transition-target='overlay']")
    const frame = document.createElement("turbo-frame")
    frame.dataset.transitionMessage = "Getting your music ready…"
    document.body.append(frame)

    frame.dispatchEvent(new CustomEvent("turbo:before-fetch-request", { bubbles: true, detail: { url: "/home/content", fetchOptions: { headers: new Headers() } } }))
    vi.advanceTimersByTime(180)
    expect(overlay.classList.contains("is-visible")).toBe(true)
    expect(document.querySelector("[data-transition-target='message']").textContent).toBe("Getting your music ready…")

    document.dispatchEvent(new Event("turbo:frame-load"))
    vi.advanceTimersByTime(350)
    expect(overlay.classList.contains("is-visible")).toBe(false)

    frame.dispatchEvent(new CustomEvent("turbo:before-fetch-request", { bubbles: true, detail: { url: "/home/content", fetchOptions: { headers: new Headers({ "X-Sec-Purpose": "prefetch" }) } } }))
    vi.advanceTimersByTime(180)
    expect(overlay.classList.contains("is-visible")).toBe(false)
  })
})
