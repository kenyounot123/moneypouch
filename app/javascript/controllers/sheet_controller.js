import { Controller } from "@hotwired/stimulus"
import { closeOnMorph } from "helpers/dialog"

export default class extends Controller {
  static targets = ["frame"]

  open() {
    if (!this.element.open) this.element.showModal()
  }

  dismiss(event) {
    if (event.target === this.element) this.close()
  }

  close() {
    this.element.close()
  }

  closeOnSubmit(event) {
    if (!event.target.dataset.sheetStays) this.close()
  }

  closeOnSuccess(event) {
    if (event.detail.success) this.close()
  }

  closeOnMorph(event) {
    closeOnMorph(this.element, event)
  }

  forget() {
    this.frameTarget.removeAttribute("src")
  }
}
