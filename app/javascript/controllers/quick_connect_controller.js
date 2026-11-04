import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["message"]
  static values = { statusUrl: String, modal: Boolean }

  connect() {
    this.poll()
    this.timer = setInterval(() => this.poll(), 3000)
  }

  disconnect() {
    clearInterval(this.timer)
  }

  async poll() {
    try {
      const response = await fetch(this.statusUrlValue, { headers: { Accept: "application/json" } })
      const result = await response.json()
      if (result.status === "connected") {
        clearInterval(this.timer)
        if (this.hasModalValue && this.modalValue) {
          const dialog = document.getElementById("reconnect-dialog")
          if (dialog && typeof dialog.close === "function") dialog.close()
          document.querySelectorAll(".connection-alert").forEach(alert => alert.remove())
          if (window.Turbo) {
            window.Turbo.visit(window.location.href, { action: "replace" })
          } else {
            window.location.reload()
          }
        } else {
          window.location.assign(result.redirect_url)
        }
      }
      if (result.status === "error" || result.status === "expired") {
        if (this.hasMessageTarget) {
          this.messageTarget.textContent = result.message || "This code expired. Please try again."
        }
        clearInterval(this.timer)
      }
    } catch (_error) {
      // Ignore network errors and continue polling
    }
  }
}
