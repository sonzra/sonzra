import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["bar", "artwork", "thumbnail"]

  connect() {
    if (!this.hasBarTarget || !this.hasArtworkTarget || !this.hasThumbnailTarget) return

    this.boundUpdate = this.update.bind(this)
    this.coverImage = this.artworkTarget.querySelector("img")
    if (!this.coverImage) return

    this.syncThumbnail()

    window.addEventListener("scroll", this.boundUpdate, { passive: true })
    window.addEventListener("resize", this.boundUpdate)
    this.update()
  }

  disconnect() {
    window.removeEventListener("scroll", this.boundUpdate)
    window.removeEventListener("resize", this.boundUpdate)
  }

  update() {
    const headerHeight = this.barTarget.getBoundingClientRect().height
    const artworkBottom = this.artworkTarget.getBoundingClientRect().bottom
    this.barTarget.classList.toggle("is-artwork-condensed", artworkBottom <= headerHeight)
  }

  syncThumbnail() {
    if (!this.coverImage?.currentSrc) return

    this.thumbnailTarget.src = this.coverImage.currentSrc
  }
}
