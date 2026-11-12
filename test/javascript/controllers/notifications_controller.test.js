import { Application } from "@hotwired/stimulus"
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest"
import NotificationsController from "../../../app/javascript/controllers/notifications_controller.js"

describe("notifications controller", () => {
  let application
  let controller
  let fetchMock

  beforeEach(async () => {
    fetchMock = vi.fn(async (url, options = {}) => {
      if (options.method === "POST" && url === "/notifications/mark_all_read") {
        return {
          ok: true,
          status: 200,
          json: async () => ({ success: true })
        }
      }
      return { ok: true, json: async () => [] }
    })
    vi.stubGlobal("fetch", fetchMock)

    const metaCsrf = document.createElement("meta")
    metaCsrf.name = "csrf-token"
    metaCsrf.content = "mock-csrf-token"
    document.head.appendChild(metaCsrf)

    document.body.innerHTML = `
      <div class="redesign-notification-hub" data-controller="notifications" data-notifications-url-value="/notifications">
        <button type="button" class="redesign-notification-hub__toggle" data-notifications-target="toggle" data-action="notifications#toggle" aria-expanded="false">
          <span id="notifications_badge">
            <span class="redesign-notification-badge">2</span>
          </span>
        </button>
        <div class="redesign-notification-hub__panel" data-notifications-target="panel" hidden>
          <div class="redesign-notification-hub__header">
            <h3>Notifications</h3>
            <button type="button" class="redesign-notification-hub__mark-all" data-action="notifications#markAllAsRead" data-url="/notifications/mark_all_read">Mark all as read</button>
          </div>
          <div id="notifications_list" class="redesign-notification-hub__list" data-notifications-target="list">
            <div id="notification_1" class="redesign-notification-card redesign-notification-card--unread">
              <span class="redesign-notification-card__dot"></span>
              <span class="redesign-notification-card__title">Track 1</span>
              <button class="redesign-notification-card__read-btn">Read</button>
            </div>
            <div id="notification_2" class="redesign-notification-card redesign-notification-card--unread">
              <span class="redesign-notification-card__dot"></span>
              <span class="redesign-notification-card__title">Track 2</span>
              <button class="redesign-notification-card__read-btn">Read</button>
            </div>
          </div>
        </div>
      </div>
    `

    application = Application.start()
    application.register("notifications", NotificationsController)
    await new Promise((resolve) => setTimeout(resolve, 0))
    const element = document.querySelector('[data-controller="notifications"]')
    controller = application.getControllerForElementAndIdentifier(element, "notifications")
  })

  afterEach(() => {
    application.stop()
    vi.restoreAllMocks()
    document.body.innerHTML = ""
  })

  it("toggles the notification panel visibility and updates aria-expanded", () => {
    const toggleBtn = controller.toggleTarget
    const panel = controller.panelTarget

    expect(panel.hidden).toBe(true)
    expect(toggleBtn.getAttribute("aria-expanded")).toBe("false")

    toggleBtn.click()
    expect(panel.hidden).toBe(false)
    expect(toggleBtn.getAttribute("aria-expanded")).toBe("true")

    toggleBtn.click()
    expect(panel.hidden).toBe(true)
    expect(toggleBtn.getAttribute("aria-expanded")).toBe("false")
  })

  it("closes the panel on outside click", () => {
    controller.toggle()
    expect(controller.panelTarget.hidden).toBe(false)

    document.dispatchEvent(new MouseEvent("click", { bubbles: true }))
    expect(controller.panelTarget.hidden).toBe(true)
  })

  it("closes the panel on Escape key", () => {
    controller.toggle()
    expect(controller.panelTarget.hidden).toBe(false)

    document.dispatchEvent(new KeyboardEvent("keydown", { key: "Escape", bubbles: true }))
    expect(controller.panelTarget.hidden).toBe(true)
  })

  it("marks all notifications as read and updates badge", async () => {
    const markAllBtn = document.querySelector(".redesign-notification-hub__mark-all")
    markAllBtn.click()
    await new Promise((resolve) => setTimeout(resolve, 10))

    expect(fetchMock).toHaveBeenCalledWith("/notifications/mark_all_read", expect.anything())
    const unreadCards = document.querySelectorAll(".redesign-notification-card--unread")
    expect(unreadCards.length).toBe(0)
    const badgePill = document.querySelector(".redesign-notification-badge")
    expect(badgePill).toBeNull()
  })
})
