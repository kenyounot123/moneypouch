import { Controller } from "@hotwired/stimulus"
import { write } from "controllers/support/write"

// P9. Connects to data-controller="keyboard" on <body>.
// Sole owner of: row selection, the undo stack, the toast, the help dialog.
// Drives the bar through the quick-add outlet (focus, edit).
//
// The undo stack is DOM: <div id="undo_entries" data-turbo-permanent> in the
// layout. The server appends one <template data-keyboard-target="entry"
// data-method data-url data-line> per write (transactions/change.turbo_stream),
// so the client never computes an inverse and never knows route shapes.
// Undo replays the newest entry verbatim with undo=1, and the server declares
// no inverse for a replay, so undo pops and never pushes. Max 50: oldest
// removed in entryTargetConnected. Survives morphs and Turbo visits, ends on reload.

const UNDO_LIMIT = 50
const DOUBLE_D_MS = 600

export default class extends Controller {
  static targets = ["row", "entry", "toast", "help"]
  static outlets = ["quick-add"]

  selectedId = null   // row element id ("transaction_42"); survives a morph
  selectedIndex = -1  // fallback position when the selected row is gone
  pendingD = null     // timestamp of the first `d`

  // keydown@document. Dispatch table; nothing fires while typing in a field
  // except Escape, which blurs it (the bar's own Esc handling ran first).
  // Modifier keys (meta/ctrl/alt) are never shortcuts.
  press(event) {
    // if (this.helpTarget.open) { if (event.key === "?") this.toggleHelp(); return }  // dialog handles Esc
    // if (inTextField(event.target)) { if (event.key === "Escape") event.target.blur(); return }
    // switch (event.key) {
    //   "n", "/": preventDefault; this.quickAddOutlet.focus()
    //   "j": this.move(+1)   "k": this.move(-1)
    //   "e": this.edit()     "d": this.d()      "u": this.undo()     "?": this.toggleHelp()
    // }
    throw new Error("not implemented")
  }

  // Clamped at both ends (P9 lane 9). Sets aria-selected on exactly one row,
  // scrollIntoView({ block: "nearest" }). Must paint inside one frame (16ms p95).
  move(delta) {
    throw new Error("not implemented")
  }

  // After a refresh morph, rows reconnect. Re-apply aria-selected by selectedId;
  // if that row is gone (discarded), select the row now at selectedIndex.
  rowTargetConnected(row) {
    throw new Error("not implemented")
  }

  edit() {
    // const row = this.selectedRow(); if (!row) return
    // this.quickAddOutlet.edit({ url: row.dataset.transactionUrl, line: row.dataset.transactionLine })
    throw new Error("not implemented")
  }

  // First `d` arms; a second within 600ms discards. A slow second `d` re-arms.
  d() {
    throw new Error("not implemented")
  }

  async discard() {
    // const row = this.selectedRow(); if (!row) return
    // await write("DELETE", row.dataset.transactionUrl)
    //   (the server's change stream adds the restoration entry and the toast)
    throw new Error("not implemented")
  }

  async undo() {
    // const entry = this.entryTargets.at(-1); if (!entry) return
    // const { method, url, line } = entry.dataset
    // entry.remove()
    // const result = await write(method.toUpperCase(), url, { line, undo: 1 })
    // offline: put the entry back, toast "Couldn't undo. Try again."
    // gone:    toast "Already undone."
    throw new Error("not implemented")
  }

  // Cap the stack at 50 by dropping the oldest entry.
  entryTargetConnected() {
    // if (this.entryTargets.length > UNDO_LIMIT) this.entryTargets[0].remove()
    throw new Error("not implemented")
  }

  toggleHelp() {
    // this.helpTarget.open ? this.helpTarget.close() : this.helpTarget.showModal()
    throw new Error("not implemented")
  }

  toast(message) {
    throw new Error("not implemented") // show, auto-hide after ~4s, replace if one is showing
  }
}
