import { Controller } from "@hotwired/stimulus"

const OPTION = "flex cursor-pointer items-center rounded-sm px-2.5 py-1.5"
const SIZES = {
  small: {
    form: "relative w-[140px] max-w-full",
    field: "h-7 rounded-sm px-2.5 text-sm",
    list: "absolute top-full left-0 z-10 mt-1 w-56 text-sm",
  },
  large: {
    form: "flex w-full flex-col",
    field: "h-11 rounded-md px-3 text-md",
    list: "mt-1 w-full text-md",
  },
}
const TRANSFER_ICON = `<span class="icon icon--transfer size-3.5 text-tertiary" aria-hidden="true"></span>`

export default class extends Controller {
  static targets = ["category"]
  static values = { categories: Array, size: { type: String, default: "small" } }

  open({ currentTarget, params: { url, category } }) {
    this.close()
    this.row = currentTarget.closest("li") ?? this.element
    this.label = this.categoryTargets.find((target) => this.row.contains(target)).querySelector("button")
    this.label.hidden = true
    this.form = this.editor(url)
    this.label.before(this.form)
    this.field.value = category
    this.field.focus()
    this.field.select()
    this.render()
  }

  // Removing the focused field fires blur, which calls close again before this call finishes.
  close() {
    const form = this.form
    if (!form) return

    this.form = null
    this.label.hidden = false
    form.remove()
  }

  editor(url) {
    const form = document.createElement("form")
    form.action = url
    form.method = "post"
    const size = SIZES[this.sizeValue]
    form.className = size.form
    form.dataset.turboFrame = "_top"
    form.innerHTML = `
      <input type="hidden" name="_method" value="patch">
      <input type="hidden" name="categorization[transfer]" value="0">
      <input name="categorization[category]" role="combobox" aria-label="Category" aria-autocomplete="list" aria-expanded="true" aria-controls="category-picker-list"
        autocomplete="off" spellcheck="false" placeholder="Category"
        class="${size.field} w-full border border-(--ring-color-focus) bg-level-2 outline-none shadow-[0_0_0_3px_color-mix(in_oklab,var(--ring-color-focus)_22%,transparent)] placeholder:text-tertiary">
      <div id="category-picker-list" role="listbox" class="${size.list} max-h-[250px] overflow-y-auto rounded-md border border-primary bg-level-2 p-1 shadow-control"></div>`
    this.field = form.querySelector("[role=combobox]")
    this.list = form.querySelector("[role=listbox]")
    this.transfer = form.querySelector("[name='categorization[transfer]']")
    this.field.addEventListener("input", () => this.render())
    this.field.addEventListener("keydown", (event) => this.keydown(event))
    this.field.addEventListener("blur", () => this.close())
    this.list.addEventListener("mousedown", (event) => this.press(event))
    this.list.addEventListener("mousemove", (event) => this.point(event))
    form.addEventListener("turbo:submit-start", () => this.close())
    return form
  }

  render(index = 0) {
    const typed = this.field.value.trim()
    const names = this.categoriesValue.filter((name) => name.toLowerCase().startsWith(typed.toLowerCase()))
    const exact = names.some((name) => name.toLowerCase() === typed.toLowerCase())
    this.items = names.map((name) => ({ name }))
    if (typed && !exact && typed.toLowerCase() !== "transfer") this.items.push({ name: typed, isNew: true })
    if ("transfer".startsWith(typed.toLowerCase())) this.items.push({ name: "Transfer", transfer: true })
    this.index = Math.min(index, this.items.length - 1)
    this.list.hidden = this.items.length === 0
    this.list.replaceChildren(...this.items.flatMap((item, position) => this.entry(item, position)))
    this.field.setAttribute("aria-expanded", String(!this.list.hidden))

    if (this.index >= 0) {
      this.field.setAttribute("aria-activedescendant", `category-picker-option-${this.index}`)
      document.getElementById(`category-picker-option-${this.index}`).scrollIntoView({ block: "nearest" })
    } else {
      this.field.removeAttribute("aria-activedescendant")
    }
  }

  entry(item, position) {
    if (item.transfer && position > 0) {
      const divider = document.createElement("div")
      divider.setAttribute("role", "presentation")
      divider.className = "mx-1 my-1 h-px bg-(--border-color-secondary)"
      return [ divider, this.option(item, position) ]
    } else {
      return [ this.option(item, position) ]
    }
  }

  option(item, position) {
    const option = document.createElement("div")
    option.id = `category-picker-option-${position}`
    option.dataset.index = position
    option.setAttribute("role", "option")
    option.setAttribute("aria-selected", String(position === this.index))
    option.className = `${OPTION} ${position === this.index ? "bg-level-3" : ""}`

    const label = document.createElement("span")

    if (item.isNew) {
      const name = document.createElement("span")
      name.className = "font-medium"
      name.textContent = item.name
      label.append("New category ", name)
    } else if (item.transfer) {
      option.classList.add("gap-2")
      option.insertAdjacentHTML("afterbegin", TRANSFER_ICON)
      label.className = "flex-1 font-medium"
      label.textContent = item.name
      const hint = document.createElement("span")
      hint.className = "text-xs text-tertiary"
      hint.textContent = "Not spending"
      option.append(label, hint)
      return option
    } else {
      label.textContent = item.name
    }

    option.append(label)
    return option
  }

  keydown(event) {
    if (event.key === "ArrowDown" && this.items.length) {
      event.preventDefault()
      this.render((this.index + 1) % this.items.length)
    } else if (event.key === "ArrowUp" && this.items.length) {
      event.preventDefault()
      this.render((this.index + this.items.length - 1) % this.items.length)
    } else if (event.key === "Tab" && this.index >= 0) {
      event.preventDefault()
      this.field.value = this.items[this.index].name
      this.render()
    } else if (event.key === "Enter") {
      event.preventDefault()
      this.save()
    } else if (event.key === "Escape") {
      event.preventDefault()
      const label = this.label
      this.close()
      label.focus()
    }
  }

  // A popup drawn under a resting pointer gets mouse events too, and only a real move selects.
  point(event) {
    const moved = this.pointer && (this.pointer.x !== event.screenX || this.pointer.y !== event.screenY)
    this.pointer = { x: event.screenX, y: event.screenY }
    const option = event.target.closest("[data-index]")

    if (moved && option && Number(option.dataset.index) !== this.index) {
      this.render(Number(option.dataset.index))
    }
  }

  press(event) {
    event.preventDefault()
    const option = event.target.closest("[data-index]")

    if (option) {
      this.index = Number(option.dataset.index)
      this.save()
    }
  }

  // The editor closes as the request starts, because a morph keeps the focused field and the old label beside the new one.
  save() {
    const item = this.items[this.index]
    if (item) this.field.value = item.name
    this.transfer.value = item?.transfer ? "1" : "0"
    this.label.textContent = this.field.value.trim() || "Uncategorized"
    this.form.requestSubmit()
  }
}
