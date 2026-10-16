import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["button", "panel"]

  toggle() {
    this.panelTarget.hidden = !this.panelTarget.hidden
    this.buttonTarget.setAttribute("aria-expanded", !this.panelTarget.hidden)
  }

  keepOpenThroughMorph(event) {
    if ([...this.buttonTargets, ...this.panelTargets].includes(event.target)) event.preventDefault()
  }
}
