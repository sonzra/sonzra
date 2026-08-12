import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "toggle", "menu" ]

  toggle(event) {
    event.stopPropagation()
    const expanded = this.toggleTarget.getAttribute("aria-expanded") === "true"
    this.toggleTarget.setAttribute("aria-expanded", String(!expanded))
    this.menuTarget.hidden = expanded
  }
}
