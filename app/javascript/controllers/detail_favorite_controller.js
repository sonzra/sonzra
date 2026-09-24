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
    this.render()

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

  render() {
    this.element.classList.toggle("is-active", this.favoritedValue)
    this.element.setAttribute("aria-label", this.favoritedValue ? "Remove from favourites" : "Add to favourites")
    this.element.setAttribute("title", this.favoritedValue ? "Remove from favourites" : "Add to favourites")
  }
}
