import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    dialogId: { type: String, default: "reconnect-dialog" }
  }

  connect() {
    this.handleFrameLoad = this.handleFrameLoad.bind(this)
    this.handleBackdropClick = this.handleBackdropClick.bind(this)
    this.element.addEventListener("turbo:frame-load", this.handleFrameLoad)
    if (this.element.tagName === "DIALOG") {
      this.element.addEventListener("click", this.handleBackdropClick)
    }
  }

  disconnect() {
    this.element.removeEventListener("turbo:frame-load", this.handleFrameLoad)
    if (this.element.tagName === "DIALOG") {
      this.element.removeEventListener("click", this.handleBackdropClick)
    }
  }

  handleFrameLoad() {
    if (this.element.tagName === "DIALOG" && !this.element.open) {
      if (typeof this.element.showModal === "function") {
        this.element.showModal()
      }
    }
  }

  handleBackdropClick(event) {
    if (event.target === this.element) {
      this.close(event)
    }
  }

  open(event) {
    const dialog = document.getElementById(this.dialogIdValue) || (this.element.tagName === "DIALOG" ? this.element : null)
    if (dialog && typeof dialog.showModal === "function") {
      if (!dialog.open) {
        dialog.showModal()
      }
    }
  }

  close(event) {
    if (event) {
      event.preventDefault()
    }
    const dialog = document.getElementById(this.dialogIdValue) || this.element.closest("dialog") || (this.element.tagName === "DIALOG" ? this.element : null)
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
