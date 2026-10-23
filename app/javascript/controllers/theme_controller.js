import { Controller } from "@hotwired/stimulus"

// Shows the chosen mode or theme before the server answers.
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
