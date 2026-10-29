# Trends

## Sub-features

- `/trends` (`TrendsController#show`, `Trends` in `app/models/trends.rb`) reads the signed-in user's kept transactions over the last 12 months, this month included. `<h1>Trends</h1>`, then sections that each have an `h2` with an id and `aria-labelledby`. The page streams from `[user, :transactions]`, so it refreshes when a transaction changes.
- Empty state while fewer than two full past months have data (`Trends::FULL_MONTHS_NEEDED`, this month does not count): `Trends fill in once you have two full months of transactions.` with `[role=meter][aria-label="Full months"]` (`aria-valuemax=2`) and `N of 2 months`.
- `#glance-heading` Year at a glance: the span on the right (`Nov 2025–Oct 2026`), the sentence `You earned $X and spent $Y, for a net of +$Z.` (the net clause only when it is positive), an Income and Spent legend, and `[role=group][aria-label=Months]` with 12 links to `/transactions?month=YYYY-MM`. The strip runs row-reverse, so the first link in the DOM is this month (`aria-label="Oct (present) · income $2,400 · spent $653"`) and the last is the oldest. This month is drawn faded with `present` under its name, and a month with a positive net shows `Net +$N`.
- `#categories-heading` Spending by category: a heat grid with month initials (full abbreviations from `lg`) and a `Present month` column. One `li` per spending category, by 12-month total, linking to `/categories/:id?month=<this month>` (`Uncategorized` has no link). Cells carry `title="Nov · $244.03"`, this month's cell is outlined with a dashed border, and the right column shows this month's amount over `usually $X` (the median of the last six full months, shown when at least two of them are positive). A screen-reader `table` has the caption `Spending by category and month`.
- Right column, each section only when it has something (side by side from `2xl`): `#notes-heading` Good news (up to four notes such as `September was your lowest Groceries month in 7 months.` and `Your net was positive in 3 of the last 6 months.`; category notes link), `#recurring-heading` Recurring charges (`$X a month` on the right; a charge needs three months, one row a month, amounts within 20%, and a last charge within 45 days; rows read `Usually on the 8th`), and `#income-heading` Income (`Last 12 months`; each source's name and total, plus `Usually arrives on the 1st and 15th` when its days repeat, `TrendsHelper`).

## How to get to it (user POV)

Sidebar, Trends.

## Driving it with mp.mjs

- `mp.mjs goto /trends --port N`, then `mp.mjs js '[...document.querySelectorAll("main section h2")].map(h => h.id + ":" + h.innerText)' --port N` lists the sections present.
- `mp.mjs query 'Trends.new(User.find_by(username: "demo").transactions, today: Date.current).ready?'` says which state to expect.
- Month links: `mp.mjs js '[...document.querySelectorAll("[role=group][aria-label=Months] a")].map(a => a.getAttribute("aria-label"))' --port N`. `mp.mjs click '[role=group][aria-label=Months] a' --port N` opens this month's ledger.
- Empty state: sign in as a new account (see [onboarding.md](onboarding.md)), `goto /trends`, and read `[role=meter][aria-label="Full months"]`'s `aria-valuenow`.
- `mp.mjs resize 375 812 --port N` prints `scrollWidth=375`; the month strip scrolls inside itself on a phone.

## Gotchas

- The demo data from `bin/rails "dev:transactions[N]"` spreads over 365 days, so the page is ready, but which notes and recurring charges show depends on the random rows.
