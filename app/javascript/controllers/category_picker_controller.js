import { Controller } from "@hotwired/stimulus"

const OPTION = "flex cursor-pointer items-center rounded-sm px-2.5 py-1.5"

export default class extends Controller {
  static targets = ["category"]
  static values = { categories: Array }

  open({ currentTarget, params: { url, category } }) {
    this.close()
    this.row = currentTarget.closest("li")
    this.label = this.categoryTargets.find((target) => this.row.contains(target))
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
    form.className = "relative shrink-0"
    form.innerHTML = `
      <input type="hidden" name="_method" value="patch">
      <input name="categorization[category]" role="combobox" aria-label="Category" aria-autocomplete="list" aria-expanded="true" aria-controls="category-picker-list"
        autocomplete="off" spellcheck="false" placeholder="Category"
        class="h-7 w-[140px] rounded-sm border border-(--ring-color-focus) bg-level-2 px-2.5 text-sm outline-none shadow-[0_0_0_3px_color-mix(in_oklab,var(--ring-color-focus)_22%,transparent)] placeholder:text-tertiary">
      <div id="category-picker-list" role="listbox" class="absolute top-full left-0 z-10 mt-1 max-h-[250px] w-56 overflow-y-auto rounded-md border border-primary bg-level-2 p-1 text-sm shadow-control"></div>`
    this.field = form.querySelector("[role=combobox]")
    this.list = form.querySelector("[role=listbox]")
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
    if (typed && !exact) this.items.push({ name: typed, isNew: true })
    this.index = Math.min(index, this.items.length - 1)
    this.list.hidden = this.items.length === 0
    this.list.replaceChildren(...this.items.map((item, position) => this.option(item, position)))
    this.field.setAttribute("aria-expanded", String(!this.list.hidden))

    if (this.index >= 0) {
      this.field.setAttribute("aria-activedescendant", `category-picker-option-${this.index}`)
      this.list.children[this.index].scrollIntoView({ block: "nearest" })
    } else {
      this.field.removeAttribute("aria-activedescendant")
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
      label.querySelector("button").focus()
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
    if (this.index >= 0) this.field.value = this.items[this.index].name
    this.label.querySelector("button").textContent = this.field.value.trim() || "Uncategorized"
    this.form.requestSubmit()
  }
}
