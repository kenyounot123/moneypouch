export const NEEDS_CATEGORY = '[aria-label="Needs a category"]'

let remembered = []

export function remember(ids) {
  remembered = ids
}

export function takeFirst() {
  const rows = remembered.map((id) => document.getElementById(id))
  remembered = []
  return rows.find((row) => row?.querySelector(NEEDS_CATEGORY))
}
