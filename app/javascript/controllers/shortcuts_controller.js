import { Controller } from "@hotwired/stimulus"

const KEYMAP = {
  "/": "search",
  ArrowLeft: "previousMonth",
  ArrowRight: "nextMonth",
}
const CHARACTER_KEYS = new Set(["/"])
const FIELDS = "input, textarea, select, [contenteditable]"
const SEARCH = '[aria-label="Search transactions"]'

let searchOnArrival = false

export default class extends Controller {
  static targets = ["previousMonth", "nextMonth"]
  static values = { transactionsUrl: String, singleKey: Boolean }

  connect() {
    if (searchOnArrival && !document.documentElement.hasAttribute("data-turbo-preview")) {
      searchOnArrival = false
      document.querySelector(SEARCH)?.focus()
    }
  }

  press(event) {
    const action = KEYMAP[event.key]
    if (!action || this.busy(event)) return

    // Shift stays allowed for a character key, because some layouts need it to type "/".
    if (CHARACTER_KEYS.has(event.key)) {
      if (this.singleKeyValue) this[action](event)
    } else if (!event.shiftKey) {
      this[action](event)
    }
  }

  busy(event) {
    return event.metaKey || event.ctrlKey || event.altKey || event.isComposing || event.defaultPrevented || event.repeat ||
      event.target.closest?.(FIELDS) || document.querySelector("dialog[open]")
  }

  search(event) {
    event.preventDefault()
    const field = document.querySelector(SEARCH)

    if (field) {
      field.focus()
    } else {
      searchOnArrival = true
      Turbo.visit(this.transactionsUrlValue)
    }
  }

  previousMonth(event) {
    this.step(event, this.previousMonthTargets)
  }

  nextMonth(event) {
    this.step(event, this.nextMonthTargets)
  }

  // The phone and desktop layouts each render the month steps, and only one of them shows.
  step(event, links) {
    const link = links.find((target) => target.checkVisibility())

    if (link) {
      event.preventDefault()
      link.click()
    }
  }
}
