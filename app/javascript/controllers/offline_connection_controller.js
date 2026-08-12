import { Controller } from "@hotwired/stimulus"

const CHECK_INTERVAL = 5_000

export default class extends Controller {
  static targets = [ "status", "retry", "navigationLink" ]

  connect() {
    this.boundCheck = this.check.bind(this)
    window.addEventListener("online", this.boundCheck)
    this.check()
    this.checkInterval = window.setInterval(this.boundCheck, CHECK_INTERVAL)
  }

  disconnect() {
    window.removeEventListener("online", this.boundCheck)
    window.clearInterval(this.checkInterval)
    window.clearTimeout(this.reloadTimeout)
  }

  preventNavigation(event) {
    event.preventDefault()
    this.showOffline()
  }

  async check(event) {
    event?.preventDefault()
    if (this.checking || this.connected) return

    this.checking = true
    this.setStatus("checking", "Checking connection…")
    this.retryTarget.disabled = true

    try {
      const response = await fetch("/up", { cache: "no-store" })
      if (!response.ok) throw new Error("Sonzra is unavailable")

      this.connected = true
      this.setStatus("online", "Back online")
      this.retryTarget.hidden = true
      this.reloadTimeout = window.setTimeout(() => window.location.reload(), 700)
    } catch (_) {
      this.showOffline()
    } finally {
      this.checking = false
      if (!this.connected) this.retryTarget.disabled = false
    }
  }

  showOffline() {
    this.setStatus("offline", "Offline — downloads only")
  }

  setStatus(state, message) {
    this.statusTarget.dataset.state = state
    this.statusTarget.textContent = message
    this.statusTarget.title = message
    this.statusTarget.setAttribute("aria-label", message)
  }
}
