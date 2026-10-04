// P8. Pure functions, no DOM. Lives under controllers/ because config/importmap.rb
// pins only that tree (pin_all_from "app/javascript/controllers") and P5-P9 may not
// edit the importmap. eagerLoadControllersFrom registers only *_controller files,
// so this module is imported, never registered.

/** @typedef {{ label: string, lower: string, count: number, latest: string }} Entry */

// Wire tuples -> Entry[], lowercased once per fetch, not per keystroke.
export function readCompletions({ names, categories }) {
  // names:      [[name, count, "2026-09-26"], ...] -> Entry
  // categories: ["Food", ...] -> Entry with count 0, latest ""
  throw new Error("not implemented")
}

// The token the popup completes, or null.
//   "#fo|"            -> { kind: "category", query: "fo", start: 0, end: 3 }
//   "lunch 12 #fo|od" -> { kind: "category", query: "food", start: 9, end: 14 } (whole token replaced)
//   "blu|"            -> { kind: "name", query: "blu", start: 0, end: 3 }
//   "blue bo|"        -> { kind: "name", query: "blue bo", start: 0, end: 7 }
//   "coffee 5|"       -> null
// Names: the caret is inside the leading run of plain words (before the first
// amount, date, or #token). The query is that run up to the caret, so multi-word
// names like "Blue Bottle" keep completing past the first space. The span to
// replace is the whole leading run.
export function tokenAt(text, caret) {
  throw new Error("not implemented")
}

// Prefix matches before contains matches; within each, count desc, then latest desc.
// Case-insensitive. Excludes an exact match of the query (nothing to complete).
// One pass, two buckets, sort each bucket (<= a few hundred) then slice.
export function rank(entries, query, limit = 8) {
  throw new Error("not implemented")
}
