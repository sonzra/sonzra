import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { state: { type: String, default: "idle" } }
  static targets = ["label"]

  connect() { this.apply() }
  setState(event) { this.stateValue = event.currentTarget.dataset.state }
  stateValueChanged() { this.apply() }
  apply() {
    this.element.dataset.logoState = this.stateValue
    if (this.hasLabelTarget) this.labelTarget.textContent = this.stateValue
  }
}
