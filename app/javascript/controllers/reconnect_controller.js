import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    dialogId: { type: String, default: "reconnect-dialog" }
  }

  open(event) {
    const dialog = document.getElementById(this.dialogIdValue)
    if (dialog && typeof dialog.showModal === "function") {
      dialog.showModal()
    }
  }

  close(event) {
    if (event) {
      event.preventDefault()
    }
    const dialog = document.getElementById(this.dialogIdValue) || this.element.closest("dialog")
    if (dialog && typeof dialog.close === "function") {
      dialog.close()
    }
  }

  dismiss(event) {
    if (event) {
      event.preventDefault()
    }
    this.element.remove()
  }
}
