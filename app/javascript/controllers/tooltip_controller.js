import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.tooltip = document.createElement("div")
    this.tooltip.className = "sonzra-tooltip"
    this.tooltip.role = "tooltip"
    this.tooltip.hidden = true
    document.body.append(this.tooltip)

    this.pointerOver = (event) => this.show(event.target.closest("button, a, input"))
    this.pointerOut = (event) => {
      if (event.relatedTarget?.closest?.("button, a, input") === this.activeElement) return
      this.hide()
    }
    this.focusIn = (event) => this.show(event.target.closest("button, a, input"))
    this.focusOut = () => this.hide()

    this.element.addEventListener("pointerover", this.pointerOver)
    this.element.addEventListener("pointerout", this.pointerOut)
    this.element.addEventListener("focusin", this.focusIn)
    this.element.addEventListener("focusout", this.focusOut)
    this.removeNativeTitles(this.element)
  }

  disconnect() {
    this.element.removeEventListener("pointerover", this.pointerOver)
    this.element.removeEventListener("pointerout", this.pointerOut)
    this.element.removeEventListener("focusin", this.focusIn)
    this.element.removeEventListener("focusout", this.focusOut)
    this.tooltip?.remove()
  }

  show(element) {
    const label = this.labelFor(element)
    if (!label || element?.disabled) return this.hide()

    this.activeElement = element
    element.removeAttribute("title")
    this.tooltip.textContent = label
    this.tooltip.hidden = false

    const bounds = element.getBoundingClientRect()
    const tooltipBounds = this.tooltip.getBoundingClientRect()
    const left = Math.min(Math.max(bounds.left + (bounds.width - tooltipBounds.width) / 2, 12), window.innerWidth - tooltipBounds.width - 12)
    const top = bounds.top - tooltipBounds.height - 9 < 12 ? bounds.bottom + 9 : bounds.top - tooltipBounds.height - 9
    this.tooltip.style.left = `${left}px`
    this.tooltip.style.top = `${top}px`
  }

  hide() {
    this.activeElement = null
    if (this.tooltip) this.tooltip.hidden = true
  }

  labelFor(element) {
    return element?.getAttribute("aria-label") || element?.getAttribute("title")
  }

  removeNativeTitles(node) {
    node.querySelectorAll?.("button[title], a[title], input[title]").forEach((element) => element.removeAttribute("title"))
  }
}
