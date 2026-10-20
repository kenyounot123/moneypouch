import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["select", "field", "source"]

  match() {
    this.fieldTargets.forEach((field) => {
      const select = this.selectTargets.find((target) => target.value === field.dataset.kind)
      const source = this.sourceTargets.find((target) => field.contains(target))

      field.toggleAttribute("data-matched", Boolean(select))
      source.textContent = select?.dataset.header ?? ""
    })
  }
}
