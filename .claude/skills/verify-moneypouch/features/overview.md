# Overview

## Sub-features

- The `Add a transaction` trigger with its `⌘K` chip, at the top below `lg` and sticky at the bottom, 420px wide, from `lg`. It and ⌘K or Ctrl+K open the composer in `dialog#palette` over a scrim. See [composer.md](composer.md), Q6.
- Spent total, category breakdown, and chart for one period, read by `Spending` over `Period` (`app/models/spending.rb`, `app/models/period.rb`). `/?period=week|month|year` picks it, and anything else means month. The heading reads `Spent this week`, `Spent in October`, or `Spent in 2026`. Under it, the day strip and `Day N of M`.
- Spending is `Transaction.spending`: not a transfer, and either money out or money in with a category. Money in with a category nets against it (a `+$20 #Groceries` refund lowers Groceries and the total by $20). Money in without a category, such as a paycheck, stays out.
- Where it went lists each category whose period nets above zero, largest first, with shares of the listed categories' sum. A category that only got money back is left out but still lowers the total. It lists rows without a category as `Uncategorized`, and the period's dates on the right, such as `Oct 1–31`. With no spending it reads `Nothing spent this week.`
- The chart is `Daily` for a week or month and `Monthly` for a year. Today's column is gold, the busiest column dark, and each bar's `title` reads like `Oct 3 · $27.00`.
- The Week, Month, and Year links in `nav[aria-label=Period]` swap `turbo-frame#spending`, which holds everything under the composer, and push `/?period=…` to history. The current one carries `aria-current=true`. The composer's text and focus stay. Back and Forward restore the period.
- Recent: the 5 latest kept transactions and the count of the period's, `N this week`, `N this month`, or `N in 2026`.
- Notes: every `transactions/_transaction` row (Recent, the bank block, the review, `/transactions`) shows its `transactions.note` on its own line under the name, a pencil and the text in `text-secondary`, truncated. A row with no note shows an `Add a note` chip after the name only while the row is hovered or holds focus. Clicking the note or the chip swaps in `input[aria-label=Note]` (placeholder `Add a note`) styled like the focused category field (`note_controller.js`, one per row). Enter or blur saves through `PATCH /transactions/:id/note` (`transaction[note]`; blank clears it, since `Transaction` normalizes a blank note to nil); an unchanged value just closes. Escape closes and refocuses the note or chip. `mp.mjs hover '<row> p.font-mono'` first, because the chip is `display: none` until the row is hovered.
- Adding or undoing from the composer redirects back to the same `/?period=…`, and the morph refresh updates the total, bars, and Recent in place.
- Every other open Overview of the same user follows within a moment. `Transaction` broadcasts a Turbo `refresh` to `[user, :transactions]` on each create, update, and discard, and the page subscribes with `turbo_stream_from`. Each page morphs at its own URL, so a page on Year stays on Year. The tab that made the change ignores the broadcast because its `request-id` matches.
- Sidebar with navigation. Its bottom is a Settings link to `/settings`, see [theme.md](theme.md). The current page's link carries `aria-current=page`.
- Under Recent, a link to `/transactions` reading `N transactions since Mon YYYY`, absent when the user has none.

## How to get to it (user POV)

Sign in. `/` is the Overview.

## Driving it with mp.mjs

- `mp.mjs key Meta+k --port N` opens the palette. Then `mp.mjs type '[aria-label="Add"]' hello --port N` prints `"hello"`, the field value.
- `mp.mjs key Enter --port N` presses Enter in the focused field.
- `mp.mjs shot <path>.png --port N`, then read the image.
- `mp.mjs resize 375 812 --port N` prints `scrollWidth=375` when the page has no horizontal scroll.
- `mp.mjs query 'Transaction.count'` reads the stored count.

## Gotchas

- Spending counts only outflows (`amount_in_cents < 0`) of kept rows. A paycheck or refund does not lower it.
- The period starts from `Date.current` in the browser's zone (the `time_zone` cookie). `time_zone_controller.js` writes the cookie after the page loads, so the server reads a new zone one request late. After `mp.mjs zone`, run `goto` twice before you read `Day N of M`. Check a number with `query` and the same `Date`.
- A future-dated row, such as rent typed for the 31st, counts toward the total and draws its bar.
- `bin/rails "dev:transactions[N]"` dates rows from the server's `Date.current` (UTC), so in a zone behind UTC the newest rows can land on tomorrow.
- Driving the live refresh needs two pages on one server, because the development cable adapter is in-process. Boot a second instance, then send its page to the first server with `mp.mjs js 'location.href = "http://localhost:<first port>/"' --port <second>`. Cookies ignore the port, so it stays signed in. `turbo-cable-stream-source[connected]` shows the subscription is live. `insert_all`, as in `dev:transactions`, skips callbacks and broadcasts nothing.
- Handles: `turbo-frame#spending`, the total `turbo-frame#spending p.font-sans`, the toggle `nav[aria-label=Period] a[href="/?period=week"]`.
- A link inside `turbo-frame#spending` that leaves the Overview needs `data-turbo-frame="_top"`, or Turbo looks for the frame on the next page and shows "Content missing".
- Typing in the composer field renders the preview through `GET /voucher`. Wait on the frame text before a `shot`.
