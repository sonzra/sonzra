import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["sheet", "queueAction", "resetAction", "panel"]

  connect() {
    this.boundCloseOnOutsideClick = this.closeOnOutsideClick.bind(this)
  }

  disconnect() {
    this.cancelPress()
    window.clearTimeout(this.closeTimeout)
    window.clearTimeout(this.sheetClickTimeout)
    this.resetSheetDrag()
    window.cancelAnimationFrame(this.openFrame)
    this.stopListeningForOutsideClick()
  }

  startPress(event) {
    if (event.target.closest("button, input, label, select, textarea")) return

    this.cancelPress()
    this.pressedCard = event.currentTarget
    this.pressTimeout = window.setTimeout(() => {
      this.open(this.pressedCard)
      this.shouldConsumeClick = true
    }, 550)
  }

  cancelPress() {
    window.clearTimeout(this.pressTimeout)
    this.pressTimeout = null
  }

  consumeClick(event) {
    if (!this.shouldConsumeClick) return

    this.shouldConsumeClick = false
    event.preventDefault()
    event.stopImmediatePropagation()
  }

  preventContextMenu(event) {
    event.preventDefault()
  }

  toggle(event) {
    event.preventDefault()
    event.stopPropagation()
    const card = event.currentTarget.closest(".listen-card")
    if (!card) return

    this.sheetTarget.hidden ? this.open(card, event.currentTarget) : this.close()
  }

  open(card, toggle = null) {
    const playButton = card.querySelector(".listen-card__play")
    if (!playButton) return

    this.configureQueueAction(playButton)
    this.activeCard = card
    window.clearTimeout(this.closeTimeout)
    window.cancelAnimationFrame(this.openFrame)
    this.sheetTarget.hidden = false
    this.sheetTarget.classList.remove("is-closing")
    if (toggle) {
      const rect = toggle.getBoundingClientRect()
      this.sheetTarget.style.setProperty("--menu-left", `${Math.max(8, rect.right - 166)}px`)
      this.sheetTarget.style.setProperty("--menu-top", `${rect.bottom + 6}px`)
    }
    this.openFrame = window.requestAnimationFrame(() => this.sheetTarget.classList.add("is-open"))
    if (!this.isMobileSheet()) document.addEventListener("click", this.boundCloseOnOutsideClick)
  }

  close(event) {
    if (event?.type === "touchend") this.ignoreNextSheetClick()
    if (event?.type === "click" && this.shouldIgnoreSheetClick) return

    event?.preventDefault()
    event?.stopPropagation()

    if (!this.hasSheetTarget || this.sheetTarget.hidden) return

    this.cancelPress()
    this.shouldConsumeClick = false
    window.cancelAnimationFrame(this.openFrame)
    this.activeCard = null
    this.stopListeningForOutsideClick()
    if (!this.isMobileSheet()) {
      this.sheetTarget.hidden = true
      this.sheetTarget.classList.remove("is-open", "is-closing")
      return
    }

    this.sheetTarget.classList.remove("is-open")
    this.sheetTarget.classList.add("is-closing")
    window.clearTimeout(this.closeTimeout)
    this.closeTimeout = window.setTimeout(() => {
      this.sheetTarget.hidden = true
      this.sheetTarget.classList.remove("is-closing")
    }, 220)
  }

  configureQueueAction(playButton) {
    const attributes = ["source", "item-id", "reporting-url", "title", "artist", "artwork", "duration", "start-position", "resumable", "queue-url"]
    attributes.forEach((name) => this.queueActionTarget.removeAttribute(`data-player-${name}-param`))
    const values = {
      source: playButton.dataset.playerSourceParam,
      "item-id": playButton.dataset.playerItemIdParam,
      "reporting-url": playButton.dataset.playerReportingUrlParam,
      title: playButton.dataset.playerTitleParam,
      artist: playButton.dataset.playerArtistParam,
      artwork: playButton.dataset.playerArtworkParam,
      duration: playButton.dataset.playerDurationParam,
      "start-position": playButton.dataset.playerStartPositionParam,
      resumable: playButton.dataset.playerResumableParam,
      "queue-url": playButton.dataset.playerQueueUrlParam
    }
    Object.entries(values).forEach(([name, value]) => {
      if (value) this.queueActionTarget.setAttribute(`data-player-${name}-param`, value)
    })

    const resetUrl = playButton.dataset.cardOptionsResetUrlParam
    this.resetActionTarget.hidden = !resetUrl
    this.resetActionTarget.dataset.cardOptionsResetUrlParam = resetUrl || ""
  }

  async resetPlaybackPosition(event) {
    if (event.type === "touchend") this.ignoreNextSheetClick()
    if (event.type === "click" && this.shouldIgnoreSheetClick) return

    event.preventDefault()
    event.stopPropagation()

    const response = await fetch(event.currentTarget.dataset.cardOptionsResetUrlParam, {
      method: "POST",
      headers: {
        Accept: "application/json",
        "X-CSRF-Token": document.querySelector("meta[name='csrf-token']")?.content
      }
    })
    if (!response.ok) return

    this.activeCard?.remove()
    this.close()
  }

  appendToQueue(event) {
    if (event.type === "touchend") this.ignoreNextSheetClick()
    if (event.type === "click" && this.shouldIgnoreSheetClick) return

    event.preventDefault()
    event.stopPropagation()
    this.application.getControllerForElementAndIdentifier(document.documentElement, "player")?.appendQueue({
      params: this.playerParams()
    })
    this.close()
  }

  startSheetDrag(event) {
    if (!this.isMobileSheet() || event.target.closest("button")) return

    const touch = event.touches[0]
    const panelTop = this.panelTarget.getBoundingClientRect().top
    if (touch.clientY - panelTop > 56) return

    this.sheetDragStartY = touch.clientY
    this.sheetDragOffset = 0
    this.sheetTarget.classList.add("is-dragging")
  }

  dragSheet(event) {
    if (this.sheetDragStartY === undefined) return

    this.sheetDragOffset = Math.max(0, event.touches[0].clientY - this.sheetDragStartY)
    this.panelTarget.style.setProperty("--sheet-drag-offset", `${this.sheetDragOffset}px`)
    event.preventDefault()
  }

  finishSheetDrag() {
    if (this.sheetDragStartY === undefined) return

    const shouldDismiss = this.sheetDragOffset > 96
    this.resetSheetDrag()
    if (shouldDismiss) this.close()
  }

  closeOnOutsideClick(event) {
    if (!this.sheetTarget.contains(event.target)) this.close()
  }

  stopListeningForOutsideClick() {
    document.removeEventListener("click", this.boundCloseOnOutsideClick)
  }

  ignoreNextSheetClick() {
    this.shouldIgnoreSheetClick = true
    window.clearTimeout(this.sheetClickTimeout)
    this.sheetClickTimeout = window.setTimeout(() => {
      this.shouldIgnoreSheetClick = false
    }, 500)
  }

  playerParams() {
    const button = this.queueActionTarget.dataset

    return {
      source: button.playerSourceParam,
      itemId: button.playerItemIdParam,
      reportingUrl: button.playerReportingUrlParam,
      title: button.playerTitleParam,
      artist: button.playerArtistParam,
      artwork: button.playerArtworkParam,
      duration: button.playerDurationParam,
      startPosition: button.playerStartPositionParam,
      resumable: button.playerResumableParam,
      queueUrl: button.playerQueueUrlParam
    }
  }

  resetSheetDrag() {
    this.sheetDragStartY = undefined
    this.sheetDragOffset = 0
    if (!this.hasSheetTarget) return

    this.sheetTarget.classList.remove("is-dragging")
    if (this.hasPanelTarget) this.panelTarget.style.removeProperty("--sheet-drag-offset")
  }

  isMobileSheet() {
    return window.matchMedia("(max-width: 760px)").matches
  }
}
