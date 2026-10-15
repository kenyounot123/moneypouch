import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "readout", "key" ]

  show({ params: { label } }) {
    this.readoutTarget.textContent = label
    if (this.hasKeyTarget) this.keyTarget.hidden = true
  }

  clear() {
    this.readoutTarget.textContent = ""
    if (this.hasKeyTarget) this.keyTarget.hidden = false
  }
}
