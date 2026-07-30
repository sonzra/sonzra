import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { url: String }

  visit(event) {
    if (event.defaultPrevented || event.button !== 0 || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return
    if (event.target.closest("a, button, input, label, select, textarea")) return

    if (window.Turbo) {
      window.Turbo.visit(this.urlValue)
    } else {
      window.location.assign(this.urlValue)
    }
  }
}
