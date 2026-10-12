import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["name", "label"]
  static values = { url: String }

  open({ currentTarget, params: { text } }) {
    this.close()
    this.trigger = currentTarget
    this.labelTargets.forEach((label) => label.hidden = true)
    this.form = this.editor()
    this.nameTarget.after(this.form)
    this.field.value = text || ""
    this.original = this.field.value
    this.field.focus()
  }

  // Moving focus off the field fires blur, so the form is forgotten first and the blur save finds nothing to send.
  close(refocus = false) {
    const form = this.form
    if (!form) return

    this.form = null
    this.labelTargets.forEach((label) => label.hidden = false)
    if (refocus) this.trigger.focus()
    form.remove()
  }

  editor() {
    const form = document.createElement("form")
    form.action = this.urlValue
    form.method = "post"
    form.className = "flex py-0.5"
    form.dataset.turboFrame = "_top"
    form.innerHTML = `
      <input type="hidden" name="_method" value="patch">
      <input name="transaction[note]" aria-label="Note" placeholder="Add a note" autocomplete="off"
        class="h-7 w-full rounded-sm border border-(--ring-color-focus) bg-level-2 px-2.5 text-base outline-none shadow-[0_0_0_3px_color-mix(in_oklab,var(--ring-color-focus)_22%,transparent)] placeholder:text-tertiary">`
    this.field = form.querySelector("[name='transaction[note]']")
    this.field.addEventListener("keydown", (event) => this.keydown(event))
    this.field.addEventListener("blur", () => this.save())
    form.addEventListener("turbo:submit-start", () => this.close())
    return form
  }

  keydown(event) {
    if (event.key === "Enter") {
      event.preventDefault()
      this.save()
    } else if (event.key === "Escape") {
      event.preventDefault()
      this.close(true)
    }
  }

  save() {
    if (!this.form) return

    if (this.field.value.trim() === this.original.trim()) {
      this.close()
    } else {
      this.form.requestSubmit()
    }
  }
}
