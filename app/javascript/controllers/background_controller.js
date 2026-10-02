import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="background"
export default class extends Controller {
  static values = { theme: String }

  connect() {
    const cookie = document.cookie
      .split("; ")
      .find((entry) => entry.startsWith("theme="))

    const theme = cookie && decodeURIComponent(cookie.slice("theme=".length))
    if (theme) this.themeValue = theme
  }

  toggle(event) {
    document.documentElement.dataset.theme = event.currentTarget.dataset.theme
  }
}
