import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["message"]
  static values = { statusUrl: String }

  connect() {
    this.poll()
    this.timer = setInterval(() => this.poll(), 3000)
  }

  disconnect() {
    clearInterval(this.timer)
  }

  async poll() {
    const response = await fetch(this.statusUrlValue, { headers: { Accept: "application/json" } })
    const result = await response.json()
    if (result.status === "connected") window.location.assign(result.redirect_url)
    if (result.status === "error" || result.status === "expired") {
      this.messageTarget.textContent = result.message || "This code expired. Please try again."
      clearInterval(this.timer)
    }
  }
}
