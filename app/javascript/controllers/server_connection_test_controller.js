import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  async run(event) {
    event.preventDefault()
    const form = event.currentTarget
    const button = form.querySelector("button")
    if (button.disabled) return

    button.disabled = true
    const originalLabel = button.textContent
    button.textContent = "Testing…"

    try {
      const response = await fetch(form.action, {
        method: "POST",
        headers: { Accept: "application/json", "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content }
      })
      const result = await response.json()
      this.showFeedback(result.message || "Couldn’t test this server connection.")
    } catch (_) {
      this.showFeedback("Couldn’t test this server connection.")
    } finally {
      button.disabled = false
      button.textContent = originalLabel
    }
  }

  showFeedback(message) {
    this.application.getControllerForElementAndIdentifier(document.documentElement, "player")?.showFeedback(message)
  }
}
