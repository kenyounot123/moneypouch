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

  clear() {
    this.composerOutlet.clear()
  }

  keepOpen(event) {
    if (event.detail.attributeName === "open") event.preventDefault()
  }
}
