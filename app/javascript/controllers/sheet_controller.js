import { Controller } from "@hotwired/stimulus"

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

  // The page morphs after every save, and a morph would strip the open attribute without closing the modal.
  keepClosed(event) {
    if (event.target === this.element && event.detail.attributeName === "open") {
      event.preventDefault()
      this.close()
    }
  }

  forget() {
    this.frameTarget.removeAttribute("src")
  }
}
