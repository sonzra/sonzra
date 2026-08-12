import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "menu", "toggle" ]

  connect() {
    this.closeWhenOutside = this.closeWhenOutside.bind(this)
    this.closeOnEscape = this.closeOnEscape.bind(this)
    document.addEventListener("click", this.closeWhenOutside)
    document.addEventListener("keydown", this.closeOnEscape)
  }

  disconnect() {
    document.removeEventListener("click", this.closeWhenOutside)
    document.removeEventListener("keydown", this.closeOnEscape)
  }

  toggle(event) {
    event.stopPropagation()
    this.menuTarget.hidden ? this.open() : this.close()
  }

  open() {
    this.menuTarget.hidden = false
    this.toggleTarget.setAttribute("aria-expanded", "true")
  }

  close() {
    this.menuTarget.hidden = true
    this.toggleTarget.setAttribute("aria-expanded", "false")
  }

  closeOnAction(event) {
    if (event.target.closest("a, button")) this.close()
  }

  closeWhenOutside(event) {
    if (!this.element.contains(event.target)) this.close()
  }

  closeOnEscape(event) {
    if (event.key === "Escape") this.close()
  }
}
