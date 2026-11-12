import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["toggle", "panel", "list", "badge"]
  static values = {
    url: String
  }

  connect() {
    this.boundCloseOnOutside = this.closeOnOutside.bind(this)
    this.boundCloseOnEscape = this.closeOnEscape.bind(this)
    document.addEventListener("click", this.boundCloseOnOutside)
    document.addEventListener("keydown", this.boundCloseOnEscape)
  }

  disconnect() {
    document.removeEventListener("click", this.boundCloseOnOutside)
    document.removeEventListener("keydown", this.boundCloseOnEscape)
  }

  toggle(event) {
    event?.stopPropagation()
    const isHidden = this.panelTarget.hidden
    this.panelTarget.hidden = !isHidden
    this.toggleTarget.setAttribute("aria-expanded", String(isHidden))
    if (isHidden) {
      this.panelTarget.focus?.()
    }
  }

  close() {
    if (!this.panelTarget.hidden) {
      this.panelTarget.hidden = true
      this.toggleTarget.setAttribute("aria-expanded", "false")
    }
  }

  closeOnOutside(event) {
    if (!this.element.contains(event.target)) {
      this.close()
    }
  }

  closeOnEscape(event) {
    if (event.key === "Escape" && !this.panelTarget.hidden) {
      this.close()
      this.toggleTarget.focus()
    }
  }

  async markAllAsRead(event) {
    event.preventDefault()
    const form = event.currentTarget.closest("form") || event.currentTarget
    const url = form.action || form.dataset.url || "/notifications/mark_all_read"

    try {
      const response = await fetch(url, {
        method: "POST",
        headers: {
          "Accept": "text/vnd.turbo-stream.html, application/json",
          "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content
        }
      })

      if (response.ok) {
        if (this.hasListTarget) {
          this.listTarget.querySelectorAll(".redesign-notification-card--unread").forEach((card) => {
            card.classList.remove("redesign-notification-card--unread")
            card.querySelector(".redesign-notification-card__dot")?.remove()
            card.querySelector(".redesign-notification-card__read-btn")?.remove()
          })
        }
        const badge = document.getElementById("notifications_badge")
        if (badge) {
          const pill = badge.querySelector(".redesign-notification-badge")
          if (pill) pill.remove()
        }
        const markAllBtn = this.element.querySelector(".redesign-notification-hub__mark-all")
        if (markAllBtn) markAllBtn.remove()
      }
    } catch (_) {}
  }
}
