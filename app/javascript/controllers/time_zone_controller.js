import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    const zone = Intl.DateTimeFormat().resolvedOptions().timeZone
    document.cookie = `time_zone=${encodeURIComponent(zone)}; path=/; max-age=31536000; samesite=lax`
  }
}
