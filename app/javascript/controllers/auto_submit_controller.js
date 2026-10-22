import { Controller } from "@hotwired/stimulus"

// Submits the field's form as soon as its value changes.
export default class extends Controller {
  submit() {
    this.element.form.requestSubmit()
  }
}
