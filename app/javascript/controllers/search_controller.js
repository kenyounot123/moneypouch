import { Controller } from "@hotwired/stimulus"
import { parseDay } from "controllers/composer/calendar"
import { splitInput, suggest } from "controllers/search/suggestions"

const KEYMAP = {
  open: {
    ArrowDown: "nextOption",
    ArrowUp: "previousOption",
    Tab: "pickOption",
    Enter: "pickOption",
    Backspace: "removeLast",
    Escape: "dismiss",
  },
  closed: {
    ArrowDown: "reopen",
    Backspace: "removeLast",
    Escape: "leave",
  },
}

const OPTION = "flex cursor-pointer items-center gap-2.5 rounded-sm px-2.5 py-1.5 text-sm"
const HEADING = "px-2.5 pt-2 pb-1 text-xs text-tertiary"
const SWATCHES = {
  category: "bg-current text-category",
  date: "bg-current text-date",
  amount: "bg-current text-amount",
  status: "bg-highlight",
  account: "bg-data",
  text: "bg-data-soft",
}

let merchants = null
let refocus = false

export default class extends Controller {
  static targets = ["form", "query", "token", "remove", "input", "popup"]
  static values = { categories: Array, accounts: Array, suggestionsUrl: String, today: String }

  connect() {
    this.options = []
    this.index = -1
    this.dismissed = false
    if (refocus && !document.documentElement.hasAttribute("data-turbo-preview")) {
      refocus = false
      this.inputTarget.focus()
    }
  }

  focus(event) {
    if (event.target.closest("a, input")) return
    this.inputTarget.focus()
  }

  keepFocus() {
    refocus = true
  }

  suggest() {
    this.dismissed = false
    this.load()
    this.refresh(true)
  }

  close() {
    this.options = []
    this.render()
  }

  async load() {
    if (merchants) return
    merchants = []
    try {
      const response = await fetch(this.suggestionsUrlValue, { headers: { Accept: "application/json" } })
      merchants = response.ok ? await response.json() : []
    } catch {
      merchants = []
    }
    this.refresh(false)
  }

  refresh(reset) {
    const { current } = splitInput(this.inputTarget.value)
    this.options = this.dismissed || document.activeElement !== this.inputTarget ? [] : suggest(current, this.catalog)
    this.index = reset ? (current ? 0 : -1) : Math.min(this.index, this.options.length - 1)
    this.render()
  }

  keydown(event) {
    const keys = KEYMAP[this.options.length ? "open" : "closed"]
    const action = keys[event.key]
    if (action && !event.isComposing && this[action](event) !== false) event.preventDefault()
  }

  press(event) {
    event.preventDefault()
    const target = event.target.closest("[data-index]")
    if (target) this.pick(this.options[target.dataset.index])
  }

  nextOption() {
    this.index = (this.index + 1) % this.options.length
    this.render()
  }

  previousOption() {
    this.index = (this.index - 1 + this.options.length) % this.options.length
    this.render()
  }

  pickOption() {
    if (this.index < 0) return false
    this.pick(this.options[this.index])
  }

  reopen() {
    this.dismissed = false
    this.refresh(true)
  }

  dismiss() {
    this.dismissed = true
    this.close()
  }

  leave() {
    this.inputTarget.blur()
  }

  removeLast() {
    if (this.inputTarget.value || !this.removeTargets.length) return false
    refocus = true
    Turbo.visit(this.removeTargets.at(-1).href)
  }

  pick(option) {
    this.go([...splitInput(this.inputTarget.value).done, option.token])
  }

  submit(event) {
    event.preventDefault()
    const { done, current } = splitInput(this.inputTarget.value)
    this.go(current ? [...done, current] : done)
  }

  pivot({ currentTarget }) {
    const token = currentTarget.dataset.searchTokenParam
    if (!this.raws.includes(token)) this.go([token], false)
  }

  go(words, fromField = true) {
    refocus = fromField
    const url = new URL(this.formTarget.action)
    const query = [...this.raws, ...words].join(" ")
    if (query) url.searchParams.set("q", query)
    for (const field of this.formTarget.querySelectorAll("input[type=hidden]:not([data-search-target])")) url.searchParams.set(field.name, field.value)
    Turbo.visit(url)
  }

  render() {
    const input = this.inputTarget
    const popup = this.popupTarget
    popup.hidden = !this.options.length
    input.setAttribute("aria-expanded", String(!popup.hidden))
    popup.replaceChildren(...this.rows())
    if (this.index >= 0) {
      input.setAttribute("aria-activedescendant", this.optionId(this.index))
      document.getElementById(this.optionId(this.index))?.scrollIntoView({ block: "nearest" })
    } else {
      input.removeAttribute("aria-activedescendant")
    }
  }

  rows() {
    let group = null
    return this.options.flatMap((option, index) => {
      const heading = option.group === group ? [] : [element("div", HEADING, option.group)]
      group = option.group
      return [...heading, this.row(option, index)]
    })
  }

  row(option, index) {
    const row = element("div", `${OPTION} ${index === this.index ? "bg-level-3" : ""}`)
    row.id = this.optionId(index)
    row.dataset.index = index
    row.setAttribute("role", "option")
    row.setAttribute("aria-selected", String(index === this.index))
    row.append(element("span", `size-2 shrink-0 rounded-[2px] ${SWATCHES[option.kind]}`), element("span", "min-w-0 flex-1 truncate", option.label))
    if (option.count) row.append(element("span", "shrink-0 font-mono text-xs text-tertiary", String(option.count)))
    return row
  }

  optionId(index) {
    return `search-option-${index}`
  }

  get catalog() {
    return {
      categories: this.categoriesValue,
      accounts: this.accountsValue,
      merchants: merchants ?? [],
      today: parseDay(this.todayValue),
      present: new Set(this.raws),
    }
  }

  get raws() {
    return this.tokenTargets.map((token) => token.dataset.raw)
  }
}

function element(tag, className, text) {
  const node = document.createElement(tag)
  node.className = className
  if (text) node.textContent = text
  return node
}
