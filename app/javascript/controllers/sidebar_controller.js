import { Controller } from "@hotwired/stimulus"
import { closeOnMorph } from "helpers/dialog"

export default class extends Controller {
  static targets = [ "toggle", "opener", "sheet" ]

  shortcut(event) {
    if (!(event.metaKey || event.ctrlKey) || event.key.toLowerCase() !== "b") return
    event.preventDefault()
    this.toggle()
  }

  toggle() {
    const collapsing = document.documentElement.dataset.sidebar !== "collapsed"
    const state = collapsing ? "collapsed" : "expanded"

    document.documentElement.dataset.sidebar = state
    document.cookie = `sidebar=${state}; path=/; max-age=31536000; samesite=lax`
    this.toggleTarget.setAttribute("aria-expanded", String(!collapsing))
  }

  open() {
    if (!this.sheetTarget.open) this.sheetTarget.showModal()
  }

  close() {
    this.sheetTarget.close()
  }

  dismiss(event) {
    if (event.target === this.sheetTarget) this.close()
  }

  closeOnMorph(event) {
    closeOnMorph(this.sheetTarget, event)
  }

  closeOnDesktop() {
    if (this.sheetTarget.open && !this.openerTarget.checkVisibility()) this.close()
  }
}
