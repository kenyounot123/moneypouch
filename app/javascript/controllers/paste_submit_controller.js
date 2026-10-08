import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  submit(event) {
    if (event.inputType === "insertFromPaste") this.element.requestSubmit()
  }
}
