import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "toggle" ]

  toggle() {
    const collapsing = document.documentElement.dataset.sidebar !== "collapsed"
    const state = collapsing ? "collapsed" : "expanded"

    document.documentElement.dataset.sidebar = state
    document.cookie = `sidebar=${state}; path=/; max-age=31536000; samesite=lax`
    this.toggleTarget.setAttribute("aria-expanded", String(!collapsing))
  }
}
