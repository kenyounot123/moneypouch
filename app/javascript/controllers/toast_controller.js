import { Controller } from "@hotwired/stimulus"

const SHOWN_MS = 5000
const FADE_MS = 200

export default class extends Controller {
  connect() {
    this.element.showPopover()
    this.fading = setTimeout(() => this.element.classList.add("opacity-0"), SHOWN_MS - FADE_MS)
    this.removing = setTimeout(() => this.element.remove(), SHOWN_MS)
  }

  disconnect() {
    clearTimeout(this.fading)
    clearTimeout(this.removing)
  }
}
