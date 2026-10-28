import { addMonths } from "controllers/composer/calendar"

const WORDS = /"[^"]*"?|\S+/g

const MONTHS = ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December"]
const DATES = [
  { token: "@today", label: "Today", words: ["today"] },
  { token: "@yesterday", label: "Yesterday", words: ["yesterday"] },
  { token: "@7d", label: "Last 7 days", words: ["last", "7", "7d", "days"] },
  { token: "@30d", label: "Last 30 days", words: ["last", "30", "30d", "days"] },
  { token: "@90d", label: "Last 90 days", words: ["last", "90", "90d", "days"] },
  { token: "@year", label: "This year", words: ["this", "year"] },
]
const STATUSES = [
  { token: "?", label: "Needs a category", words: ["needs", "category", "uncategorized"] },
  { token: "+", label: "Money in", words: ["money", "in", "income", "deposits"] },
  { token: "-", label: "Money out", words: ["money", "out", "spending", "expenses"] },
]
const TYPED_IN = { name: "Typed in", token: "in:typed" }
const NUMBER = "\\$?(\\d+(?:\\.\\d{1,2})?)"
const RANGE = new RegExp(`^${NUMBER}(?:-|\\.\\.)${NUMBER}$`)
const NUMBER_ONLY = new RegExp(`^${NUMBER}$`)
const EXACTLY = { marker: "=", token: "=", label: "Exactly" }
const COMPARISONS = [{ marker: ">", token: ">", label: "Over" }, { marker: "<", token: "<", label: "Under" }, EXACTLY]
const GUIDE = [
  { kind: "category", label: "Category", example: "#dining", marker: "#" },
  { kind: "account", label: "Account", example: "in:amex", marker: "in:" },
  { kind: "date", label: "Date", example: "@sep  @7d", marker: "@" },
  { kind: "amount", label: "Amount", example: ">50  20..80", marker: ">" },
  { kind: "text", label: "Name or note", example: "coffee" },
  { kind: "text", label: "Mix any of them", example: "#dining >30 @sep" },
]

// The marker a word starts with decides which kind of token it can still become, and each handler lists that kind's completions.
const MARKERS = [
  [/^#/, (word, context) => categories(word.slice(1), context, true)],
  [/^in:/i, (word, context) => accounts(word.slice(3), context, true)],
  [/^@/, (word, context) => dates(word.slice(1).toLowerCase(), context, true)],
  [/^[<>=$]/, (word) => amounts(word)],
  [/^[?+-]$/, (word) => statuses(word, true)],
]

export function splitInput(input) {
  const words = input.match(WORDS) ?? []
  const last = words.at(-1)
  const open = last?.startsWith('"') && !(last.length > 1 && last.endsWith('"'))
  if (!last || (/\s$/.test(input) && !open)) return { done: words, current: "" }
  return { done: words.slice(0, -1), current: last }
}

export function suggest(word, context) {
  if (!word) return defaults(context)
  const marked = MARKERS.find(([pattern]) => pattern.test(word))
  if (marked) return marked[1](word, context)
  return plain(word.replace(/^"/, "").replace(/"$/, ""), context)
}

function phrase(text) {
  return /\s/.test(text) ? `"${text.replaceAll('"', "")}"` : text
}

function defaults({ merchants, today, present }) {
  const last = addMonths(today, -1)
  return [
    ...(present.has("?") ? [] : [option("Suggested", "status", "Needs a category", "?")]),
    option("Suggested", "date", "Last month", monthToken(last.getFullYear(), last.getMonth())),
    ...merchants.slice(0, 3).map((merchant) => merchantOption(merchant)),
    ...GUIDE.map(({ kind, label, example, marker }) => option("Search by", kind, label, null, { example, marker })),
  ]
}

function plain(word, context) {
  const text = word.toLowerCase()
  return [
    ...merchantOptions(text, context),
    ...categories(text, context, false),
    ...accounts(text, context, false),
    ...amounts(word),
    ...dates(text, context, false),
    ...statuses(text, false),
    option("Search", "text", `Names and notes containing “${word}”`, phrase(word)),
  ]
}

function merchantOptions(text, { merchants }) {
  return merchants.filter((merchant) => merchant.name.toLowerCase().includes(text)).slice(0, 4).map(merchantOption)
}

function merchantOption(merchant) {
  return option("Merchants", "text", merchant.name, `"${merchant.name.replaceAll('"', "")}"`, { count: merchant.count })
}

function categories(text, { categories }, marked) {
  const key = squash(text)
  const found = categories.filter((category) => {
    const name = squash(category.name)
    return name.startsWith(key) || (!marked && key.length >= 3 && name.includes(key))
  })
  const options = found.map((category) => option("Categories", "category", category.name, category.token, { count: category.count }))
  return marked && !options.length ? [typed(`#${text}`, "category")] : options
}

function accounts(text, { accounts }, marked) {
  const key = squash(text)
  const named = [...accounts, TYPED_IN].filter((account) => squash(account.name).startsWith(key) || words(account.name).some((word) => word.startsWith(text.toLowerCase())))
  const options = (key || marked ? named : []).map((account) => option("Accounts", "account", account.name, account.token))
  return marked && !options.length ? [typed(`in:${text}`, "account")] : options
}

function amounts(word) {
  const range = word.match(RANGE)
  if (range) return [option("Amount", "amount", `${dollars(range[1])}–${dollars(range[2])}`, `${range[1]}..${range[2]}`)]

  const number = word.replace(/^[<>=]/, "").match(NUMBER_ONLY)?.[1]
  if (!number) return []
  const chosen = COMPARISONS.find(({ marker }) => word.startsWith(marker)) ?? (word.startsWith("$") ? EXACTLY : null)
  return (chosen ? [chosen] : COMPARISONS).map(({ token, label }) => option("Amount", "amount", `${label} ${dollars(number)}`, `${token}${number}`))
}

function dates(text, { today }, marked) {
  const presets = DATES.filter((date) => date.token.slice(1).startsWith(text) || (!marked && date.words.some((word) => word.startsWith(text))))
  const months = text.length >= 3 ? MONTHS.flatMap((name, index) => (name.toLowerCase().startsWith(text) ? [monthOption(index, today)] : [])) : []
  const options = [...presets.map(({ token, label }) => option("Dates", "date", label, token)), ...months]
  return marked && !options.length && text ? [typed(`@${text}`, "date")] : options
}

function monthOption(index, today) {
  const year = index > today.getMonth() ? today.getFullYear() - 1 : today.getFullYear()
  return option("Dates", "date", `${MONTHS[index]} ${year}`, monthToken(year, index))
}

function monthToken(year, index) {
  return `@${year}-${String(index + 1).padStart(2, "0")}`
}

function statuses(text, marked) {
  const found = STATUSES.filter((status) => (marked ? status.token === text : text.length >= 2 && status.words.some((word) => word.startsWith(text))))
  return found.map(({ token, label }) => option("Status", "status", label, token))
}

function option(group, kind, label, token, extra = {}) {
  return { group, kind, label, token, ...extra }
}

function typed(raw, kind) {
  return option("Search", kind, `Use “${raw}” as typed`, raw)
}

function dollars(number) {
  const cents = Math.round(Number(number) * 100)
  const whole = Math.floor(cents / 100).toLocaleString("en-US")
  return cents % 100 === 0 ? `$${whole}` : `$${whole}.${String(cents % 100).padStart(2, "0")}`
}

function squash(name) {
  return name.toLowerCase().replace(/[^\p{L}\p{N}]/gu, "")
}

function words(name) {
  return name.toLowerCase().match(/[\p{L}\p{N}]+/gu) ?? []
}
