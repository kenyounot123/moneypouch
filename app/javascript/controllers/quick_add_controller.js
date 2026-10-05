import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["field", "undo", "failure"]
  static values = { draftUrl: String }

  connect() {
    this.sync()
  }

  sync() {
    this.url = this.previewUrl()
  }

  refresh() {
    const url = this.previewUrl()
    if (url === this.url) return
    this.url = url
    this.frame.src = url
  }

  keydown(event) {
    if (event.key === "z" && (event.metaKey || event.ctrlKey) && !this.fieldTarget.value && this.hasUndoTarget) {
      event.preventDefault()
      this.undoTarget.click()
    }
  }

  finish({ detail: { success, fetchResponse } }) {
    if (success || fetchResponse?.contentType?.startsWith("text/vnd.turbo-stream.html")) return
    this.forgetFailure()
    this.frame.prepend(this.failureTarget.content.cloneNode(true))
  }

  forgetFailure() {
    this.frame.querySelector("[data-failure]")?.remove()
  }

  previewUrl() {
    return `${this.draftUrlValue}?${new URLSearchParams({ line: this.fieldTarget.value })}`
  }

  get frame() {
    return this.element.querySelector("turbo-frame#draft")
  }
}
