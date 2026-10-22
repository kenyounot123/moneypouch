import { Controller } from "@hotwired/stimulus"

// Shows the chosen theme before the server answers.
export default class extends Controller {
  choose(event) {
    document.documentElement.dataset.theme = event.currentTarget.dataset.theme
  }
}
