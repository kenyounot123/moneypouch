import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["form"]

  connect() {
    if (!this.element.open) this.element.showModal()
  }

  dismiss(event) {
    if (event.target === this.element) this.close()
  }

  close() {
    this.element.close()
  }

  markSeen() {
    this.formTarget.requestSubmit()
  }

  keepOpen(event) {
    if (event.detail.attributeName === "open") event.preventDefault()
  }
}
