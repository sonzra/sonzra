import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["toggle", "panel", "drawer", "list"]
  static values = {
    url: String
  }

  connect() {
    this.closeWhenOutside = this.closeWhenOutside.bind(this)
    this.closeOnEscape = this.closeOnEscape.bind(this)
    this.closeOnNavigation = this.closeOnNavigation.bind(this)

    document.addEventListener("click", this.closeWhenOutside)
    document.addEventListener("keydown", this.closeOnEscape)
    document.addEventListener("turbo:before-visit", this.closeOnNavigation)
  }

  disconnect() {
    document.removeEventListener("click", this.closeWhenOutside)
    document.removeEventListener("keydown", this.closeOnEscape)
    document.removeEventListener("turbo:before-visit", this.closeOnNavigation)
  }

  toggle(event) {
    event?.stopPropagation()
    const panel = this.panel
    if (!panel) return

    panel.hidden ? this.open() : this.close()
  }

  open() {
    if (!this.panel) return

    this.panel.hidden = false
    this.toggleTarget.setAttribute("aria-expanded", "true")
    this.panel.focus?.()
  }

  close() {
    if (!this.panel) return

    this.panel.hidden = true
    if (this.hasToggleTarget) this.toggleTarget.setAttribute("aria-expanded", "false")
  }

  closeWhenOutside(event) {
    if (!this.element.contains(event.target)) this.close()
  }

  closeOnEscape(event) {
    if (event.key === "Escape" && this.panel && !this.panel.hidden) {
      this.close()
      this.toggleTarget.focus()
    }
  }

  closeOnNavigation() {
    this.close()
  }

  async markAllAsRead(event) {
    event.preventDefault()
    const form = event.currentTarget.closest("form") || event.currentTarget
    const url = form.action || form.dataset.url || "/notifications/mark_all_read"

    try {
      const response = await fetch(url, {
        method: "POST",
        headers: {
          "Accept": "text/vnd.turbo-stream.html",
          "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content
        }
      })

      if (response.ok) {
        this.listTarget.querySelectorAll(".redesign-notification-card--unread, .is-unread").forEach((item) => {
          item.classList.remove("redesign-notification-card--unread", "is-unread")
          item.querySelector(".redesign-notification-card__dot")?.remove()
          item.querySelector(".redesign-notification-card__read-btn")?.remove()
        })
        document.getElementById("notifications_badge")?.remove()

        const stream = await response.text()
        if (stream && window.Turbo) window.Turbo.renderStreamMessage(stream)
      }
    } catch (_) {}
  }

  markRead(event) {
    const url = event.params?.url
    if (!url) return

    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.getAttribute("content")
    fetch(url, {
      method: "PATCH",
      headers: {
        "X-CSRF-Token": csrfToken,
        "Accept": "text/vnd.turbo-stream.html"
      }
    }).then(response => {
      if (response.ok) return response.text()
    }).then(html => {
      if (html && window.Turbo) window.Turbo.renderStreamMessage(html)
    }).catch(() => {})
  }

  readAndNavigate(event) {
    const url = event.params?.url
    if (!url) return

    const csrfToken = document.querySelector('meta[name="csrf-token"]')?.getAttribute("content")
    fetch(url, {
      method: "PATCH",
      headers: {
        "X-CSRF-Token": csrfToken,
        "Accept": "text/vnd.turbo-stream.html"
      }
    }).then(response => {
      if (response.ok) return response.text()
    }).then(html => {
      if (html && window.Turbo) window.Turbo.renderStreamMessage(html)
    }).catch(() => {})
    this.close()
  }

  get panel() {
    if (this.hasPanelTarget) return this.panelTarget
    if (this.hasDrawerTarget) return this.drawerTarget
    return null
  }
}
