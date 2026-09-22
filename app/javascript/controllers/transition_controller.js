import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["overlay", "message", "detail"]

  connect() {
    this.boundBeforeVisit = this.beforeVisit.bind(this)
    this.boundBeforeFrameFetch = this.beforeFrameFetch.bind(this)
    this.boundLoad = this.hide.bind(this)
    this.boundError = this.hide.bind(this)
    document.addEventListener("turbo:before-visit", this.boundBeforeVisit)
    document.addEventListener("turbo:before-fetch-request", this.boundBeforeFrameFetch)
    document.addEventListener("turbo:load", this.boundLoad)
    document.addEventListener("turbo:frame-load", this.boundLoad)
    document.addEventListener("turbo:fetch-request-error", this.boundError)
  }

  disconnect() {
    this.cancel()
    document.removeEventListener("turbo:before-visit", this.boundBeforeVisit)
    document.removeEventListener("turbo:before-fetch-request", this.boundBeforeFrameFetch)
    document.removeEventListener("turbo:load", this.boundLoad)
    document.removeEventListener("turbo:frame-load", this.boundLoad)
    document.removeEventListener("turbo:fetch-request-error", this.boundError)
  }

  beforeVisit(event) { this.showForUrl(event.detail.url) }

  beforeFrameFetch(event) {
    const frame = event.target
    if (frame?.tagName !== "TURBO-FRAME" || this.prefetchRequest(event.detail.fetchOptions?.headers)) return

    this.showForUrl(event.detail.url || frame.src, frame.dataset.transitionMessage)
  }

  prefetchRequest(headers) {
    if (!headers) return false

    const purpose = typeof headers.get === "function" ? headers.get("X-Sec-Purpose") : headers["X-Sec-Purpose"] || headers["x-sec-purpose"]
    return purpose === "prefetch"
  }

  showForUrl(url, message = null) {
    const path = typeof url === "string" ? url : url?.toString() || ""
    const fallback = path.includes("library_items") ? "Opening album" : path.includes("library/") ? "Opening your library" : path.includes("recommendation") || path.includes("sonic_graph") ? "Finding new sounds" : path.includes("server") ? "Connecting to your server" : "Taking you home"
    this.show({ message: message || fallback })
  }

  show({ message = "Opening Sonzra", delay = 180, minimum = 350 } = {}) {
    this.cancel()
    this.minimum = minimum
    this.messageTarget.textContent = message
    this.detailTarget.textContent = "Syncing the sound around you"
    this.showTimer = window.setTimeout(() => {
      this.shownAt = Date.now()
      this.overlayTarget.classList.add("is-visible")
      this.overlayTarget.setAttribute("aria-hidden", "false")
    }, delay)
  }

  hide() {
    window.clearTimeout(this.showTimer)
    if (!this.overlayTarget.classList.contains("is-visible")) return
    const elapsed = Date.now() - this.shownAt
    window.clearTimeout(this.hideTimer)
    this.hideTimer = window.setTimeout(() => {
      this.overlayTarget.classList.remove("is-visible")
      this.overlayTarget.setAttribute("aria-hidden", "true")
    }, Math.max(0, this.minimum - elapsed))
  }

  cancel() {
    window.clearTimeout(this.showTimer)
    window.clearTimeout(this.hideTimer)
  }
}
