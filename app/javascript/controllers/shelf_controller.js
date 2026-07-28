import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["content"]

  scrollLeft() {
    this.scrollBy(-1)
  }

  scrollRight() {
    this.scrollBy(1)
  }

  scrollBy(direction) {
    this.contentTarget.scrollBy({ left: this.contentTarget.clientWidth * direction * 0.8, behavior: "smooth" })
  }
}
