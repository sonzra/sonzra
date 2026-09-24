import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "toggle", "menu" ]

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
    this.isOpen() ? this.close() : this.open()
  }

  open() {
    this.toggleTarget.setAttribute("aria-expanded", "true")
    this.menuTarget.hidden = false
  }

  close({ restoreFocus = false } = {}) {
    const wasOpen = this.isOpen()
    this.toggleTarget.setAttribute("aria-expanded", "false")
    this.menuTarget.hidden = true
    if (restoreFocus && wasOpen) this.toggleTarget.focus()
  }

  closeOnAction(event) {
    if (event.target.closest("a, button")) this.close()
  }

  closeWhenOutside(event) {
    if (!this.element.contains(event.target)) this.close()
  }

  closeOnEscape(event) {
    if (event.key !== "Escape" || !this.isOpen()) return

    event.preventDefault()
    this.close({ restoreFocus: true })
  }

  isOpen() {
    return this.toggleTarget.getAttribute("aria-expanded") === "true"
  }
}
