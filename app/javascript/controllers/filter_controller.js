import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "item", "section", "links", "status", "clear"]

  connect() {
    this.texts = new Map(this.itemTargets.map((item) => [item, this.textOf(item)]))
    this.apply()
  }

  apply() {
    const typed = this.inputTarget.value.trim()
    const words = typed.toLowerCase().split(/\s+/).filter(Boolean)
    let answers = 0

    for (const item of this.itemTargets) {
      item.hidden = !words.every((word) => this.texts.get(item).includes(word))
      if (!item.hidden) answers++
    }

    for (const section of this.sectionTargets) {
      section.hidden = !section.querySelector("[data-filter-target=item]:not([hidden])")
    }

    this.linksTarget.hidden = words.length > 0
    this.clearTarget.hidden = typed === ""
    this.statusTarget.textContent = this.statusFor(typed, answers)
  }

  reset(event) {
    if (!this.inputTarget.value) return
    event.preventDefault()
    this.inputTarget.value = ""
    this.apply()
    this.inputTarget.focus()
  }

  statusFor(typed, answers) {
    if (!typed) return ""
    if (answers === 0) return `No answers for "${typed}".`
    return answers === 1 ? "1 answer" : `${answers} answers`
  }

  textOf(item) {
    const heading = item.closest("section").querySelector("h2").textContent
    return `${heading} ${item.textContent}`.toLowerCase().replace(/\s+/g, " ")
  }
}
