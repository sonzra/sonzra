import { Controller } from "@hotwired/stimulus"

const CHECK_INTERVAL = 5_000

export default class extends Controller {
  static targets = [ "status", "retry", "navigationLink" ]

  connect() {
    this.boundCheck = this.check.bind(this)
    this.boundVisibility = this.handleVisibilityChange.bind(this)
    window.addEventListener("online", this.boundCheck)
    window.addEventListener("focus", this.boundCheck)
    document.addEventListener("visibilitychange", this.boundVisibility)
    this.check()
    this.checkInterval = window.setInterval(this.boundCheck, CHECK_INTERVAL)
  }

  disconnect() {
    window.removeEventListener("online", this.boundCheck)
    window.removeEventListener("focus", this.boundCheck)
    document.removeEventListener("visibilitychange", this.boundVisibility)
    window.clearInterval(this.checkInterval)
    window.clearTimeout(this.reloadTimeout)
  }

  handleVisibilityChange() {
    if (document.visibilityState === "visible") {
      this.check()
    }
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
    this.retryTargets.forEach((target) => { target.disabled = true })

    try {
      const response = await fetch("/up", { cache: "no-store" })
      if (!response.ok) throw new Error("Sonzra is unavailable")

      this.connected = true
      this.setStatus("online", "Back online")
      this.retryTargets.forEach((target) => { target.hidden = true })
      this.reloadTimeout = window.setTimeout(() => window.location.reload(), 700)
    } catch (_) {
      this.showOffline()
    } finally {
      this.checking = false
      if (!this.connected) {
        this.retryTargets.forEach((target) => { target.disabled = false })
      }
    }
  }

  showOffline() {
    this.setStatus("offline", "Offline — downloads only")
  }

  setStatus(state, message) {
    this.statusTargets.forEach((target) => {
      target.dataset.state = state
      target.textContent = message
      target.title = message
      target.setAttribute("aria-label", message)
    })
  }
}
