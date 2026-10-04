import { Controller } from "@hotwired/stimulus"
import { write } from "controllers/support/write"

// P5, P9. Connects to data-controller="quick-add" on form#quick_add (permanent).
// Owns the line's lifecycle and nothing else:
//   mode     stash (POST /transactions) | edit (PATCH the row's url)
//   preview  sets <turbo-frame id="draft">.src; Turbo cancels the stale request
//   submit   at most one write in flight, through support/write.js
// It never knows about rows or the undo stack: the server declares each inverse.
//
// Perf marks for P5 lanes: "draft:key" on input, "draft:pills" on the frame's
// turbo:frame-render; "draft:enter" on submit, "draft:row" on turbo:morph.
export default class extends Controller {
  static targets = ["line", "frame", "submit", "label"]
  static values = { draftUrl: String, createUrl: String }

  // { url, transactionId, saved } while editing a row, else null.
  // saved = what was in the bar before `e`, put back on Esc or after the save.
  editing = null
  busy = false
  // One key per typed line, minted on the first submit of that line and kept
  // through retries (offline, lost response), so the server stores it once.
  idempotencyKey = null

  // input event. Any edit to the text means a new line: drop the key.
  preview() {
    // this.idempotencyKey = null
    // const params = new URLSearchParams({ line: this.lineTarget.value })
    // if (this.editing) params.set("transaction_id", this.editing.transactionId)
    // this.frameTarget.src = `${this.draftUrlValue}?${params}`
    throw new Error("not implemented")
  }

  // submit event (Enter or the button). Always preventDefault: writes go through write().
  async submit(event) {
    // event.preventDefault()
    // if (this.busy || this.lineTarget.value.trim() === "") return
    // this.busy = true; this.lineTarget.readOnly = true   (readOnly keeps focus; disabled would drop it)
    // const result = this.editing
    //   ? await write("PATCH", this.editing.url, { line })
    //   : await write("POST", this.createUrlValue, { line, idempotency_key: this.idempotencyKey ??= crypto.randomUUID() })
    // this.busy = false; this.lineTarget.readOnly = false
    // ok:       this.dispatch("committed"); this.reset()       (completion refetches on this)
    // rejected: keep text; the 422 stream already put the error in the frame
    // offline:  keep text and key; show "Couldn't save. Press Enter to try again."
    throw new Error("not implemented")
  }

  // Outlet API, called by keyboard#edit. Loads a row's line into the bar.
  edit({ url, line }) {
    // this.editing = { url, transactionId: idFrom(url), saved: this.lineTarget.value }
    // this.labelTarget.textContent = "Save ↵"; set line, focus, caret at end, preview()
    throw new Error("not implemented")
  }

  // Outlet API, called by keyboard on n and /.
  focus() {
    this.lineTarget.focus()
  }

  // keydown.esc on the line. Runs after completion#navigate, which stops the
  // event when Esc only closed its popup. Editing: cancel the edit and stop.
  // Not editing: let it bubble; keyboard#press blurs the bar.
  escape(event) {
    // if (!this.editing) return
    // event.stopPropagation(); this.reset()
    throw new Error("not implemented")
  }

  // Back to stash mode: label "Stash it ↵", line = editing?.saved ?? "",
  // editing = null, idempotencyKey = null, then preview().
  reset() {
    throw new Error("not implemented")
  }
}
