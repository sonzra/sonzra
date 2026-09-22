import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "dialog", "input" ]
  static values = { global: Boolean }

  connect() {
    this.boundKeydown = this.keydown.bind(this)
    if (this.globalValue) document.addEventListener("keydown", this.boundKeydown)
  }

  disconnect() {
    document.removeEventListener("keydown", this.boundKeydown)
  }

  open() {
    if (typeof this.dialogTarget.showModal === "function") {
      this.dialogTarget.showModal()
    } else {
      this.dialogTarget.setAttribute("open", "")
    }

    window.requestAnimationFrame(() => this.inputTarget.focus())
  }

  close() {
    if (typeof this.dialogTarget.close === "function") {
      this.dialogTarget.close()
    } else {
      this.dialogTarget.removeAttribute("open")
    }
  }

  closeOnBackdrop(event) {
    if (event.target === this.dialogTarget) this.close()
  }

  keydown(event) {
    if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === "k") {
      event.preventDefault()
      this.open()
    }
    if (event.key === "Escape" && this.dialogTarget.open) this.close()
  }
}
