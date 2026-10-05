import { Controller } from "@hotwired/stimulus"

const KEYMAP = {
  none: {
    Tab: "complete",
    "Mod+z": "undo",
  },
}

export default class extends Controller {
  static targets = ["field", "row", "undo", "failure"]
  static values = { draftUrl: String }

  connect() {
    this.popup = null
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
    const action = KEYMAP[this.popup?.kind ?? "none"][keyName(event)]
    if (action && this[action](event) !== false) event.preventDefault()
  }

  finish({ detail: { success, fetchResponse } }) {
    if (success || fetchResponse?.contentType?.startsWith("text/vnd.turbo-stream.html")) return
    this.forgetFailure()
    this.frame.prepend(this.failureTarget.content.cloneNode(true))
  }

  forgetFailure() {
    this.frame.querySelector("[data-failure]")?.remove()
  }

  complete() {
    const completion = this.hasRowTarget && this.rowTarget.dataset.line === this.fieldTarget.value && this.rowTarget.dataset.completion
    if (!completion || !this.caretAtEnd) return false
    this.fieldTarget.value = `${completion} `
    this.refresh()
  }

  undo() {
    if (this.fieldTarget.value || !this.hasUndoTarget) return false
    this.undoTarget.click()
  }

  previewUrl() {
    const params = new URLSearchParams({ line: this.fieldTarget.value })
    if (this.caretAtEnd) params.set("complete", "1")
    return `${this.draftUrlValue}?${params}`
  }

  get caretAtEnd() {
    const { selectionStart, selectionEnd, value } = this.fieldTarget
    return selectionStart === value.length && selectionEnd === value.length
  }

  get frame() {
    return this.element.querySelector("turbo-frame#draft")
  }
}

function keyName(event) {
  const modifier = event.metaKey || event.ctrlKey ? "Mod+" : event.shiftKey && event.key.length > 1 ? "Shift+" : ""
  return modifier + event.key
}
