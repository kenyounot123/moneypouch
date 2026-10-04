import { Turbo } from "@hotwired/turbo-rails"

// P5. The only module that sends a write. Every mutation, from the bar or the
// keyboard, takes this path, so every write ends the same way:
//   1. fetch with the CSRF token, Accept: text/vnd.turbo-stream.html
//   2. Turbo.renderStreamMessage(body): the change stream appends the server's
//      undo entry and sets the toast (or, on 422, puts the error in the pills)
//   3. on success, Turbo.visit(location.href, { action: "replace" }): a Turbo 8
//      page refresh, morphed with scroll preserved, so totals, day groups,
//      Recent, and restored rows repaint from one server render.
// Not the `refresh` stream action: Turbo 2.0.23 debounces it by 150ms, half the
// 300ms Enter-to-row budget.
//
// @param method "POST" | "PATCH" | "DELETE"
// @param url    string
// @param params object, form-encoded (e.g. { line, idempotency_key, undo: 1 })
// @returns { ok: true } | { ok: false, reason: "rejected" | "gone" | "offline" }
//   rejected  422, the stream already showed why
//   gone      404, e.g. an undo whose target was already undone elsewhere
//   offline   no response; the caller keeps its state and may retry
export async function write(method, url, params = {}) {
  throw new Error("not implemented")
}
