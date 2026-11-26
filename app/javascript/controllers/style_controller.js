import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { declarations: Object }

  connect() {
    this.apply()
    this.element.addEventListener("turbo:morph-element", this.apply)
  }

  disconnect() {
    this.element.removeEventListener("turbo:morph-element", this.apply)
  }

  apply = () => {
    for (const [ property, value ] of Object.entries(this.declarationsValue)) {
      this.element.style.setProperty(property, value)
    }
  }
}
