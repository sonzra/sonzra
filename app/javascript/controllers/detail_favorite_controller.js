import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { favorited: Boolean, url: String }

  connect() {
    this.render()
  }

  async toggle(event) {
    event.preventDefault()
    if (!this.hasUrlValue) return

    this.favoritedValue = !this.favoritedValue
    this.render({ animate: true })

    try {
      await fetch(this.urlValue, {
        method: "PATCH",
        headers: {
          Accept: "application/json",
          "Content-Type": "application/json",
          "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content
        },
        body: JSON.stringify({ favorite: this.favoritedValue })
      })
    } catch (_) {
      // The optimistic state is intentionally local. A reload restores the
      // server's state if the request could not be completed.
    }
  }

  render({ animate = false } = {}) {
    this.element.classList.toggle("is-active", this.favoritedValue)
    this.element.setAttribute("aria-label", this.favoritedValue ? "Remove from favourites" : "Add to favourites")
    this.element.removeAttribute("title")

    if (animate) {
      this.element.classList.remove("is-animating")
      void this.element.offsetWidth
      this.element.classList.add("is-animating")
    }
  }
}
