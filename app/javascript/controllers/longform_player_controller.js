import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["primaryLabel", "startOver"]

  markStarted() {
    this.primaryLabelTarget.textContent = "Continue"
    this.startOverTarget.hidden = false
  }
}
