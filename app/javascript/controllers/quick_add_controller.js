import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["field"]
  static values = { draftUrl: String }

  connect() {
    this.url = this.previewUrl()
  }

  refresh() {
    const url = this.previewUrl()
    if (url === this.url) return
    this.url = url
    this.frame.src = url
  }

  previewUrl() {
    return `${this.draftUrlValue}?${new URLSearchParams({ line: this.fieldTarget.value })}`
  }

  get frame() {
    return this.element.querySelector("turbo-frame#draft")
  }
}
