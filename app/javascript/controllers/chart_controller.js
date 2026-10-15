import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "readout" ]

  show({ params: { label } }) {
    this.readoutTarget.textContent = label
  }

  clear() {
    this.readoutTarget.textContent = ""
  }
}
