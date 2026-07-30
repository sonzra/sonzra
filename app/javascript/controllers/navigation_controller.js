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
    this.menuTarget.classList.contains("is-open") ? this.close() : this.open()
  }

  closeOnNavigation(event) {
    if (event.target.closest("a, button")) this.close()
  }

  open() {
    this.menuTarget.classList.add("is-open")
    this.toggleTarget.setAttribute("aria-expanded", "true")
    this.toggleTarget.setAttribute("aria-label", "Close navigation menu")
  }

  close() {
    this.menuTarget.classList.remove("is-open")
    this.toggleTarget.setAttribute("aria-expanded", "false")
    this.toggleTarget.setAttribute("aria-label", "Open navigation menu")
  }

  closeWhenOutside(event) {
    if (!this.element.contains(event.target)) this.close()
  }

  closeOnEscape(event) {
    if (event.key === "Escape") this.close()
  }
}
