import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dialog", "undo"]
  static outlets = ["composer"]

  open() {
    this.dialogTarget.showModal()
  }

  shortcut(event) {
    if (!(event.metaKey || event.ctrlKey)) return
    if (event.key.toLowerCase() === "k") this.toggle(event)
    if (event.key === "z") this.undo(event)
  }

  toggle(event) {
    event.preventDefault()
    this.dialogTarget.open ? this.dialogTarget.close() : this.open()
  }

  undo(event) {
    if (!this.hasUndoTarget || event.target.value) return
    event.preventDefault()
    this.undoTarget.click()
  }

  dismiss(event) {
    if (event.target === this.dialogTarget) this.dialogTarget.close()
  }

  undoTargetConnected(undo) {
    this.keepClickableAboveModal(undo.closest("[data-controller~=toast]"))
  }

  keepClickableAboveModal(toast) {
    if (this.dialogTarget.open && !this.dialogTarget.contains(toast)) this.dialogTarget.append(toast)
  }

  clear() {
    this.composerOutlet.clear()
    this.dialogTarget.querySelectorAll("[data-controller~=toast]").forEach((toast) => this.element.append(toast))
  }

  keepOpen(event) {
    if (event.detail.attributeName === "open") event.preventDefault()
  }
}
