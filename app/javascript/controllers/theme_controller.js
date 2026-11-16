import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  chooseMode(event) {
    this.element.dataset.mode = event.currentTarget.dataset.mode
  }

  chooseTheme(event) {
    this.element.dataset.theme = event.currentTarget.dataset.theme

    for (const swatch of this.element.querySelectorAll("button[data-theme]")) {
      swatch.ariaPressed = swatch === event.currentTarget
    }
  }
}
