const MONTHS = ["jan", "feb", "mar", "apr", "may", "jun", "jul", "aug", "sep", "oct", "nov", "dec"]
const WEEKDAYS = ["Su", "Mo", "Tu", "We", "Th", "Fr", "Sa"]
const DATE_FRAGMENT = /(?:^|\s)@([a-z]+(?: \d{0,2}[a-z]{0,2}(?: \d{0,4})?)?|[^\s@#]*)$/i
const KBD = "rounded-sm border border-primary bg-level-2 px-1.5 py-0.5 font-mono text-xs text-secondary"

export function parseDay(iso) {
  const [year, month, day] = iso.split("-").map(Number)
  return new Date(year, month - 1, day)
}

export function isoDay(day) {
  return [day.getFullYear(), day.getMonth() + 1, day.getDate()].map((part) => String(part).padStart(2, "0")).join("-")
}

export function sameDay(a, b) {
  return a.getTime() === b.getTime()
}

export function addDays(day, count) {
  return new Date(day.getFullYear(), day.getMonth(), day.getDate() + count)
}

export function addMonths(day, count) {
  const first = new Date(day.getFullYear(), day.getMonth() + count, 1)
  const last = new Date(first.getFullYear(), first.getMonth() + 1, 0).getDate()
  return new Date(first.getFullYear(), first.getMonth(), Math.min(day.getDate(), last))
}

export function earlier(day, max) {
  return day > max ? max : day
}

export function weeks(month) {
  const first = new Date(month.getFullYear(), month.getMonth(), 1)
  const length = new Date(month.getFullYear(), month.getMonth() + 1, 0).getDate()
  const cells = Array(first.getDay()).fill(null)
  for (let date = 1; date <= length; date++) cells.push(new Date(month.getFullYear(), month.getMonth(), date))
  while (cells.length % 7) cells.push(null)
  return Array.from({ length: cells.length / 7 }, (_, week) => cells.slice(week * 7, week * 7 + 7))
}

export function dateWord(day, today) {
  if (sameDay(day, today)) return "today"
  if (sameDay(day, addDays(today, -1))) return "yesterday"
  const word = `${MONTHS[day.getMonth()]} ${day.getDate()}`
  return day.getFullYear() === today.getFullYear() ? word : `${word} ${day.getFullYear()}`
}

// The text after an @ up to the caret. It spans spaces only when it leads with a month ("@sep 26 2025").
export function dateFragment(before) {
  const typed = before.match(DATE_FRAGMENT)?.[1]
  if (typed === undefined) return null
  if (typed.includes(" ") && !MONTHS.includes(typed.slice(0, 3).toLowerCase())) return null
  return { text: `@${typed}`, start: before.length - typed.length - 1, end: before.length }
}

export function monthTitle(day) {
  return day.toLocaleDateString("en-US", { month: "long", year: "numeric" })
}

export function dayId(day) {
  return `composer-day-${isoDay(day)}`
}

export function statusMarkup(answer) {
  if (answer.kind === "none") return `<span class="text-danger">Not a date yet</span>`
  if (answer.kind === "exact") return answer.on.toLocaleDateString("en-US", { weekday: "short", month: "short", day: "numeric", year: "numeric" })
  if (answer.kind === "partial") return "keep typing"
  return `type <span class="font-mono">9/26</span>, <span class="font-mono">sep 26</span>, <span class="font-mono">2025-03</span>`
}

export function calendarMarkup(cursor, today, max, answer) {
  const title = monthTitle(cursor)
  const nextMonthDisabled = new Date(cursor.getFullYear(), cursor.getMonth() + 1, 1) > max ? "disabled" : ""
  return `
    <div class="flex items-center justify-between px-2 pt-1.5 pb-2">
      <button type="button" tabindex="-1" data-months="-1" aria-label="Previous month" class="cursor-pointer rounded-sm px-2 text-secondary hover:bg-level-3">‹</button>
      <span class="font-medium">${title}</span>
      <button type="button" tabindex="-1" data-months="1" aria-label="Next month" class="cursor-pointer rounded-sm px-2 text-secondary hover:bg-level-3 disabled:cursor-default disabled:opacity-40" ${nextMonthDisabled}>›</button>
    </div>
    <div role="grid" aria-label="${title}" class="flex flex-col gap-0.5 px-1 text-center">
      <div role="row" class="grid grid-cols-7 gap-0.5">
        ${WEEKDAYS.map((day) => `<span role="columnheader" class="pb-1 text-xs text-tertiary">${day}</span>`).join("")}
      </div>
      ${weeks(cursor).map((week) => `<div role="row" class="grid grid-cols-7 gap-0.5">${week.map((day) => dayCell(day, cursor, today, max)).join("")}</div>`).join("")}
    </div>
    <div class="mt-1.5 px-2 pt-1.5 text-xs text-secondary">${statusMarkup(answer)}</div>
    <div class="mt-1.5 flex flex-wrap gap-x-3 gap-y-1.5 border-t border-secondary px-2 pt-2 pb-1 text-xs text-tertiary">
      <span><span class="${KBD}">←↑↓→</span> move</span><span><span class="${KBD}">↵</span> pick</span><span><span class="${KBD}">esc</span> cancel</span>
    </div>`
}

function dayCell(day, cursor, today, max) {
  if (!day) return `<span role="gridcell"></span>`
  const selected = sameDay(day, cursor)
  const future = day > max
  const look = selected ? "bg-highlight font-semibold text-on-action" : future ? "text-tertiary opacity-40" : ""
  const todayMark = sameDay(day, today) && !selected ? "underline decoration-2 underline-offset-4" : ""
  return `<button type="button" tabindex="-1" role="gridcell" id="${dayId(day)}" data-day="${isoDay(day)}" aria-selected="${selected}" ${future ? "disabled" : ""}
    class="flex h-8 cursor-pointer items-center justify-center rounded-sm font-mono text-sm disabled:cursor-default ${look} ${todayMark}">${day.getDate()}</button>`
}
