import { Controller } from "@hotwired/stimulus"

const WIDE = "(min-width: 80rem)"
const KEPT = "[data-help-target=sheet], [data-help-target] details, [data-help-target=opener]"
const KEPT_ATTRIBUTES = new Set(["open", "aria-expanded", "aria-controls"])
const SAVED = /(?:^|; )help=(\w+)/

export default class extends Controller {
  static targets = ["opener", "aside", "sheet"]

  connect() {
    document.documentElement.dataset.help = SAVED.exec(document.cookie)?.[1] === "open" ? "open" : "closed"
    this.reflect()
  }

  open(event) {
    if (event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return
    event.preventDefault()

    if (matchMedia(WIDE).matches) {
      this.shown ? this.close() : this.openAside()
    } else {
      this.sheetTarget.showModal()
      this.sheetTarget.focus({ preventScroll: true })
    }
  }

  close() {
    if (this.sheetTarget.open) {
      this.sheetTarget.close()
    } else {
      this.closeAside()
    }
    this.visibleOpener?.focus()
  }

  dismiss(event) {
    if (event.target === this.sheetTarget) this.close()
  }

  escape(event) {
    if (event.key !== "Escape") return
    event.preventDefault()
    this.close()
  }

  closeSheet() {
    if (this.hasSheetTarget && this.sheetTarget.open) this.sheetTarget.close()
  }

  closeOnWide() {
    if (matchMedia(WIDE).matches) this.closeSheet()
    this.reflect()
  }

  keepThroughMorph(event) {
    if (KEPT_ATTRIBUTES.has(event.detail.attributeName) && event.target.matches(KEPT)) event.preventDefault()
  }

  openAside() {
    this.remember("open")
    this.asideTarget.focus({ preventScroll: true })
  }

  closeAside() {
    this.remember("closed")
  }

  remember(state) {
    document.documentElement.dataset.help = state
    document.cookie = `help=${state}; path=/; samesite=lax`
    this.reflect()
  }

  reflect() {
    for (const opener of this.openerTargets) {
      opener.setAttribute("aria-controls", this.asideTarget.id)
      opener.setAttribute("aria-expanded", String(matchMedia(WIDE).matches && this.shown))
    }
  }

  get shown() {
    return document.documentElement.dataset.help === "open"
  }

  get visibleOpener() {
    return this.openerTargets.find((opener) => opener.checkVisibility())
  }
}
