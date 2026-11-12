import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "drawer", "toggle", "list" ]

  connect() {
    this.closeWhenOutside = this.closeWhenOutside.bind(this)
    this.closeOnEscape = this.closeOnEscape.bind(this)
    this.closeOnNavigation = this.closeOnNavigation.bind(this)

    document.addEventListener("click", this.closeWhenOutside)
    document.addEventListener("keydown", this.closeOnEscape)
    document.addEventListener("turbo:before-visit", this.closeOnNavigation)
  }

  disconnect() {
    document.removeEventListener("click", this.closeWhenOutside)
    document.removeEventListener("keydown", this.closeOnEscape)
    document.removeEventListener("turbo:before-visit", this.closeOnNavigation)
  }

  toggle(event) {
    if (event) event.stopPropagation()
    if (!this.hasDrawerTarget) return

    this.drawerTarget.hidden ? this.open() : this.close()
  }

  open() {
    if (!this.hasDrawerTarget) return

    this.drawerTarget.hidden = false
    if (this.hasToggleTarget) {
      this.toggleTarget.setAttribute("aria-expanded", "true")
    }
  }

  close() {
    if (!this.hasDrawerTarget) return

    this.drawerTarget.hidden = true
    if (this.hasToggleTarget) {
      this.toggleTarget.setAttribute("aria-expanded", "false")
    }
  }

  closeWhenOutside(event) {
    if (!this.element.contains(event.target)) {
      this.close()
    }
  }

  closeOnEscape(event) {
    if (event.key === "Escape") {
      this.close()
    }
  }

  closeOnNavigation() {
    this.close()
  }

  readAndNavigate(event) {
    const url = event.params?.url
    if (url) {
      const csrfToken = document.querySelector('meta[name="csrf-token"]')?.getAttribute("content")
      fetch(url, {
        method: "PATCH",
        headers: {
          "X-CSRF-Token": csrfToken,
          "Accept": "text/vnd.turbo-stream.html"
        }
      }).then(response => {
        if (response.ok) return response.text()
      }).then(html => {
        if (html && window.Turbo) {
          window.Turbo.renderStreamMessage(html)
        }
      }).catch(() => {})
    }
    this.close()
  }
}
