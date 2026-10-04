import { Controller } from "@hotwired/stimulus"

// P5. Connects to data-controller="time-zone" on <html>.
// Writes the browser's IANA zone to a `time_zone` cookie (same cookie pattern as
// background_controller.js). ApplicationController reads and validates it.
// No reload when it changes: the next request picks it up. The sign-in page runs
// this too, so the first authenticated page already has the cookie.
export default class extends Controller {
  connect() {
    // const zone = Intl.DateTimeFormat().resolvedOptions().timeZone
    // if (readCookie("time_zone") !== zone)
    //   document.cookie = `time_zone=${encodeURIComponent(zone)}; path=/; max-age=31536000; samesite=lax`
    throw new Error("not implemented")
  }
}
