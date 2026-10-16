import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    this.toggle()
  }

  toggle() {
    this.element.toggleAttribute("data-shown", window.scrollY > window.innerHeight)
  }

  scroll() {
    const reduced = matchMedia("(prefers-reduced-motion: reduce)").matches
    window.scrollTo({ top: 0, behavior: reduced ? "instant" : "smooth" })
  }
}
