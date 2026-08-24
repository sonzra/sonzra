import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    hasMore: Boolean,
    page: Number,
    letter: String,
    url: String
  }
  static targets = ["grid", "sentinel", "alphabet", "state"]

  connect() {
    this.loading = false
    this.observer = new IntersectionObserver(this.onSentinelVisible.bind(this), {
      rootMargin: "300px 0px"
    })
    if (this.hasSentinelTarget) {
      this.observer.observe(this.sentinelTarget)
    }
  }

  disconnect() {
    if (this.observer) {
      this.observer.disconnect()
    }
  }

  sentinelTargetConnected(element) {
    if (this.observer) {
      this.observer.observe(element)
    }
  }

  stateTargetConnected(element) {
    if (element.dataset.hasMore !== undefined) {
      this.hasMoreValue = element.dataset.hasMore === "true"
    }
    if (element.dataset.page !== undefined) {
      this.pageValue = Number(element.dataset.page) || 1
    }
    if (element.dataset.letter !== undefined) {
      this.letterValue = element.dataset.letter
    }
  }

  async onSentinelVisible(entries) {
    const entry = entries[0]
    if (!entry || !entry.isIntersecting || this.loading || !this.hasMoreValue) return

    await this.loadNextPage()
  }

  async loadNextPage() {
    this.loading = true
    const nextPage = this.pageValue + 1
    const targetUrl = this.buildUrl({ page: nextPage, letter: this.letterValue })

    try {
      const response = await fetch(targetUrl, {
        headers: { Accept: "text/vnd.turbo-stream.html" }
      })
      if (response.ok) {
        const streamHtml = await response.text()
        const turbo = typeof Turbo !== "undefined" ? Turbo : (typeof window !== "undefined" ? window.Turbo : null)
        if (typeof turbo?.renderStreamMessage === "function") {
          turbo.renderStreamMessage(streamHtml)
        }
      }
    } catch (_) {
      // Network errors will be retried on next scroll intersection
    } finally {
      this.loading = false
    }
  }

  jumpToLetter(event) {
    const letter = event.params?.letter ?? ""
    const targetUrl = this.buildUrl({ page: 1, letter })
    const turbo = typeof Turbo !== "undefined" ? Turbo : (typeof window !== "undefined" ? window.Turbo : null)
    if (typeof turbo?.visit === "function") {
      turbo.visit(targetUrl)
    } else {
      window.location.href = targetUrl
    }
  }

  buildUrl({ page, letter }) {
    const base = this.urlValue || window.location.pathname
    const url = new URL(base, window.location.origin)
    if (page > 1) {
      url.searchParams.set("page", page)
    } else {
      url.searchParams.delete("page")
    }
    if (letter) {
      url.searchParams.set("letter", letter)
    } else {
      url.searchParams.delete("letter")
    }
    return url.toString()
  }
}
