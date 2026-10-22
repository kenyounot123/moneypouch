import { Controller } from "@hotwired/stimulus"

// Puts the browser's zone in a cookie each request reads, and saves it on the user when it changes, for jobs that run without a request.
export default class extends Controller {
  static values = { saved: String, url: String }

  connect() {
    const zone = Intl.DateTimeFormat().resolvedOptions().timeZone
    document.cookie = `time_zone=${encodeURIComponent(zone)}; path=/; max-age=31536000; samesite=lax`

    if (this.urlValue && zone !== this.savedValue) this.save(zone)
  }

  save(zone) {
    const token = document.querySelector("meta[name=csrf-token]")?.content
    const body = new FormData()
    body.append("time_zone", zone)

    fetch(this.urlValue, { method: "PATCH", body, headers: { "X-CSRF-Token": token, Accept: "text/plain" }, credentials: "same-origin" })
  }
}
