import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { connectionId: Number, currentConnectionId: Number }

  switch() {
    if (this.connectionIdValue === this.currentConnectionIdValue) return

    window.Turbo?.cache.clear()
    this.application.getControllerForElementAndIdentifier(document.documentElement, "player")?.clearQueue()
  }
}
