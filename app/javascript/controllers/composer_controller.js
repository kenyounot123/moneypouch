import { Controller } from "@hotwired/stimulus"
import { addDays, addMonths, calendarMarkup, dateWord, dayId, earlier, isoDay, parseDay } from "controllers/composer/calendar"

const KEYMAP = {
  none: {
    Tab: "complete",
  },
  category: {
    ArrowDown: "nextOption",
    ArrowUp: "previousOption",
    Tab: "pickOption",
    Enter: "pickOption",
    Escape: "dismiss",
  },
  calendar: {
    ArrowLeft: "previousDay",
    ArrowRight: "nextDay",
    ArrowUp: "previousWeek",
    ArrowDown: "nextWeek",
    PageUp: "previousMonth",
    PageDown: "nextMonth",
    Tab: "pickCursor",
    Enter: "pickCursor",
    t: "pickToday",
    y: "pickYesterday",
    Escape: "removeAt",
    Printable: "leaveCalendar",
  },
}

const OPTION = "flex cursor-pointer items-center rounded-sm px-2.5 py-1.5"
const POPUP_SIZES = {
  category: ["w-56", "max-h-[250px]", "overflow-y-auto"],
  calendar: ["w-[264px]"],
}

export default class extends Controller {
  static targets = ["field", "row", "popup", "failure"]
  static values = { voucherUrl: String, categories: Array, today: String }

  connect() {
    this.popup = null
    this.sync()
  }

  sync() {
    this.dismissed = null
    this.drawn = null
    this.update()
    this.url = this.previewUrl()
  }

  refresh() {
    this.update()
    const url = this.previewUrl()
    if (url === this.url) return
    this.url = url
    this.frame.src = url
  }

  update() {
    this.popup = this.nextPopup()
    this.render()
  }

  keydown(event) {
    const keys = KEYMAP[this.popup?.kind ?? "none"]
    const name = keyName(event)
    const action = keys[name] ?? (name.length === 1 ? keys.Printable : undefined)
    if (action && this[action](event) !== false) event.preventDefault()
  }

  press(event) {
    event.preventDefault()
    const target = event.target.closest("[data-index], [data-day], [data-months]")
    if (!target) return
    if (target.dataset.index) this.pick(this.popup.items[target.dataset.index])
    if (target.dataset.day && !target.disabled) this.pickDay(parseDay(target.dataset.day))
    if (target.dataset.months) this.moveCursor(addMonths(this.popup.cursor, Number(target.dataset.months)))
  }

  // Chrome sends mouse events to a resting pointer when the popup opens or redraws under it, and only a real move selects.
  point(event) {
    const moved = event.screenX !== this.pointerX || event.screenY !== this.pointerY
    this.pointerX = event.screenX
    this.pointerY = event.screenY
    const target = moved && this.popup && this.popupTarget.contains(event.target) && event.target.closest("[data-index], [data-day]:not(:disabled)")
    if (!target) return
    if (target.dataset.index && Number(target.dataset.index) !== this.popup.index) {
      this.popup.index = Number(target.dataset.index)
      this.refresh()
    }
    if (target.dataset.day && target.dataset.day !== isoDay(this.popup.cursor)) this.moveCursor(parseDay(target.dataset.day))
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
    const completion = this.hasRowTarget && this.rowTarget.dataset.shorthand === this.fieldTarget.value && this.rowTarget.dataset.completion
    if (!completion || !this.caretAtEnd) return false
    this.fieldTarget.value = `${completion} `
    this.refresh()
  }

  nextOption() {
    this.popup.index = (this.popup.index + 1) % this.popup.items.length
    this.refresh()
  }

  previousOption() {
    this.popup.index = (this.popup.index + this.popup.items.length - 1) % this.popup.items.length
    this.refresh()
  }

  pickOption() {
    this.pick(this.popup.items[this.popup.index])
  }

  pick(item) {
    this.replaceWord(this.popup.word, `#${item.name}`)
  }

  dismiss() {
    this.dismissed = wordKey(this.popup.word)
    this.refresh()
  }

  previousDay() {
    this.moveCursor(addDays(this.popup.cursor, -1))
  }

  nextDay() {
    this.moveCursor(addDays(this.popup.cursor, 1))
  }

  previousWeek() {
    this.moveCursor(addDays(this.popup.cursor, -7))
  }

  nextWeek() {
    this.moveCursor(addDays(this.popup.cursor, 7))
  }

  previousMonth() {
    this.moveCursor(addMonths(this.popup.cursor, -1))
  }

  nextMonth() {
    this.moveCursor(addMonths(this.popup.cursor, 1))
  }

  moveCursor(day) {
    this.popup.cursor = earlier(day, this.max)
    this.refresh()
  }

  pickCursor() {
    this.pickDay(this.popup.cursor)
  }

  pickToday() {
    this.pickDay(this.today)
  }

  pickYesterday() {
    this.pickDay(addDays(this.today, -1))
  }

  pickDay(day) {
    this.replaceWord(this.popup.word, dateWord(day, this.today))
  }

  removeAt() {
    this.cutAt()
    this.refresh()
  }

  leaveCalendar() {
    this.cutAt()
    this.popup = null
    return false
  }

  cutAt() {
    const field = this.fieldTarget
    const { start } = this.popup.word
    field.value = field.value.slice(0, start) + field.value.slice(start + 1)
    field.setSelectionRange(start, start)
  }

  nextPopup() {
    const word = this.caretWord()
    if (!word) return null
    if (wordKey(word) !== this.dismissed) this.dismissed = null
    if (this.dismissed) return null
    const previous = this.popup
    if (word.text.startsWith("#")) return this.categoryPopup(word, previous?.kind === "category" ? previous : null)
    if (word.text === "@") return this.calendarPopup(word, previous?.kind === "calendar" ? previous : null)
    return null
  }

  categoryPopup(word, previous) {
    const query = word.text.slice(1).toLowerCase()
    const row = this.hasRowTarget ? this.rowTarget.dataset : {}
    const fresh = !query && row.shorthand === this.fieldTarget.value
    const inferred = fresh ? row.inferredCategory ?? null : previous ? previous.inferred : row.inferredCategory
    const names = [inferred, ...this.categoriesValue.filter((name) => name !== inferred)].filter(Boolean)
    const items = names.filter((name) => name.toLowerCase().startsWith(query)).map((name) => ({ name }))
    if (query && !names.some((name) => name.toLowerCase() === query)) items.push({ name: word.text.slice(1), isNew: true })
    if (!items.length) return null

    const index = previous?.word.text === word.text ? Math.min(previous.index, items.length - 1) : 0
    return { kind: "category", word, items, index, inferred }
  }

  calendarPopup(word, previous) {
    return { kind: "calendar", word, cursor: previous?.cursor ?? this.today }
  }

  render() {
    const drawn = popupKey(this.popup)
    if (drawn === this.drawn) return
    this.drawn = drawn

    const field = this.fieldTarget
    const popup = this.popupTarget
    field.setAttribute("aria-expanded", String(!!this.popup))
    popup.hidden = !this.popup
    if (!this.popup) {
      field.removeAttribute("aria-activedescendant")
      popup.removeAttribute("role")
      popup.replaceChildren()
      return
    }

    popup.classList.remove(...Object.values(POPUP_SIZES).flat())
    popup.classList.add(...POPUP_SIZES[this.popup.kind])
    const activeId = this.popup.kind === "category" ? this.renderCategory() : this.renderCalendar()
    field.setAttribute("aria-activedescendant", activeId)
    this.place(this.popup.word)
    document.getElementById(activeId)?.scrollIntoView({ block: "nearest" })
  }

  renderCategory() {
    const popup = this.popupTarget
    popup.setAttribute("role", "listbox")
    popup.replaceChildren(...this.popup.items.map((item, index) => this.option(item, index)))
    return `composer-option-${this.popup.index}`
  }

  option(item, index) {
    const selected = index === this.popup.index
    const option = document.createElement("div")
    option.id = `composer-option-${index}`
    option.dataset.index = index
    option.setAttribute("role", "option")
    option.setAttribute("aria-selected", String(selected))
    option.className = `${OPTION} ${selected ? "bg-level-3" : ""}`
    const label = document.createElement("span")
    if (item.isNew) {
      const name = document.createElement("span")
      name.className = "font-medium"
      name.textContent = item.name
      label.append("New category ", name)
    } else {
      label.textContent = item.name
    }
    option.append(label)
    return option
  }

  renderCalendar() {
    this.popupTarget.removeAttribute("role")
    this.popupTarget.innerHTML = calendarMarkup(this.popup.cursor, this.today, this.max)
    return dayId(this.popup.cursor)
  }

  place(word) {
    const probe = document.createElement("span")
    probe.className = "invisible absolute text-md whitespace-pre"
    probe.textContent = this.fieldTarget.value.slice(0, word.start)
    document.body.append(probe)
    const x = this.fieldTarget.getBoundingClientRect().left - this.element.getBoundingClientRect().left + probe.offsetWidth - this.fieldTarget.scrollLeft
    probe.remove()
    this.popupTarget.style.left = `${Math.max(0, Math.min(x - 8, this.element.clientWidth - this.popupTarget.offsetWidth))}px`
  }

  caretWord() {
    const field = this.fieldTarget
    if (document.activeElement !== field || field.selectionStart !== field.selectionEnd) return null
    const before = field.value.slice(0, field.selectionStart)
    const text = before.match(/\S*$/)[0]
    return { text, start: before.length - text.length, end: field.selectionStart }
  }

  replaceWord(word, text) {
    const field = this.fieldTarget
    const rest = field.value.slice(word.end).replace(/^\S*/, "").trimStart()
    field.value = `${field.value.slice(0, word.start)}${text} ${rest}`
    const caret = word.start + text.length + 1
    field.setSelectionRange(caret, caret)
    this.refresh()
  }

  previewUrl() {
    const params = new URLSearchParams({ shorthand: this.previewShorthand() })
    if (!this.popup && this.caretAtEnd) params.set("complete", "1")
    return `${this.voucherUrlValue}?${params}`
  }

  previewShorthand() {
    const { value } = this.fieldTarget
    if (!this.popup) return value
    const { word } = this.popup
    return value.slice(0, word.start) + this.previewWord() + value.slice(word.end)
  }

  // While inference is unknown (undefined) or picked, a bare # keeps the row inferring, so the row stays the
  // source of the category that leads the list. null means the row said this name has none.
  previewWord() {
    const { kind, word, items, index, inferred, cursor } = this.popup
    if (kind === "calendar") return dateWord(cursor, this.today)
    const { name } = items[index]
    return word.text === "#" && (inferred === undefined || name === inferred) ? "#" : `#${name}`
  }

  get caretAtEnd() {
    const { selectionStart, selectionEnd, value } = this.fieldTarget
    return selectionStart === value.length && selectionEnd === value.length
  }

  get today() {
    return parseDay(this.todayValue)
  }

  get max() {
    return this.today
  }

  get frame() {
    return this.element.querySelector("turbo-frame#voucher")
  }
}

function keyName(event) {
  const modifier = event.metaKey || event.ctrlKey ? "Mod+" : event.shiftKey && event.key.length > 1 ? "Shift+" : ""
  return modifier + event.key
}

function popupKey(popup) {
  if (!popup) return "none"
  const { kind, word, index, cursor, items } = popup
  return [kind, wordKey(word), index, cursor && isoDay(cursor), items?.map((item) => item.name).join("\n")].join("|")
}

function wordKey(word) {
  return `${word.start}:${word.text}`
}
