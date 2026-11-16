import { Controller } from "@hotwired/stimulus"

const COPIED_MS = 2000

export default class extends Controller {
  static targets = ["source", "button"]

  select() {
    this.sourceTarget.select()
  }

  async copy() {
    if (navigator.clipboard) {
      await navigator.clipboard.writeText(this.sourceTarget.value)
    } else {
      this.select()
      document.execCommand("copy")
    }
    const label = this.buttonTarget.textContent
    this.buttonTarget.textContent = "Copied"
    setTimeout(() => (this.buttonTarget.textContent = label), COPIED_MS)
  }
}
