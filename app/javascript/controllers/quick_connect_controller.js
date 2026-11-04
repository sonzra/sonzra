import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["message"]
  static values = { statusUrl: String, modal: Boolean }

  connect() {
    this.handleDialogClose = this.handleDialogClose.bind(this)
    this.dialogElement = this.element.closest("dialog")
    if (this.dialogElement) {
      this.dialogElement.addEventListener("close", this.handleDialogClose)
    }

    this.poll()
    this.timer = setInterval(() => this.poll(), 3000)
  }

  disconnect() {
    if (this.timer) {
      clearInterval(this.timer)
      this.timer = null
    }
    if (this.dialogElement) {
      this.dialogElement.removeEventListener("close", this.handleDialogClose)
    }
  }

  handleDialogClose() {
    if (this.timer) {
      clearInterval(this.timer)
      this.timer = null
    }
  }

  async poll() {
    const dialog = this.dialogElement || this.element.closest("dialog")
    if (dialog && !dialog.open) {
      if (this.timer) {
        clearInterval(this.timer)
        this.timer = null
      }
      return
    }

    try {
      const response = await fetch(this.statusUrlValue, { headers: { Accept: "application/json" } })
      const result = await response.json()
      if (result.status === "connected") {
        if (this.timer) {
          clearInterval(this.timer)
          this.timer = null
        }
        const isInOpenModal = Boolean(this.modalValue && (dialog ? dialog.open : document.getElementById("reconnect-dialog")?.open))
        if (isInOpenModal) {
          const targetDialog = dialog || document.getElementById("reconnect-dialog")
          if (targetDialog && typeof targetDialog.close === "function") targetDialog.close()
          document.querySelectorAll(".connection-alert").forEach(alert => alert.remove())
          if (window.Turbo) {
            window.Turbo.visit(window.location.href, { action: "replace" })
          } else {
            window.location.reload()
          }
        } else {
          const redirectUrl = result.redirect_url || "/server_connections"
          if (window.Turbo) {
            window.Turbo.visit(redirectUrl)
          } else {
            window.location.assign(redirectUrl)
          }
        }
      }
      if (result.status === "error" || result.status === "expired") {
        if (this.hasMessageTarget) {
          this.messageTarget.textContent = result.message || "This code expired. Please try again."
        }
        if (this.timer) {
          clearInterval(this.timer)
          this.timer = null
        }
      }
    } catch (_error) {
      // Ignore network errors and continue polling
    }
  }
}
