# Overview

## Sub-features

- Composer, an input labelled "Add", with the preview frame `turbo-frame#voucher`. Below `lg` it is at the top with the preview under it. At `lg` and up it floats at the bottom, 640px wide, with the preview above it. See [composer.md](composer.md).
- Spent total, category breakdown, daily bars, and Recent: the 5 latest kept transactions and the count of this month's.
- Sidebar with navigation. Its bottom is a Settings link to `/settings`, see [theme.md](theme.md). The current page's link carries `aria-current=page`.
- Under Recent, a link to `/transactions` reading `N transactions since Mon YYYY`, absent when the user has none.

## How to get to it (user POV)

Sign in. `/` is the Overview.

## Driving it with mp.mjs

- `mp.mjs type '[aria-label="Add"]' hello --port N` prints `"hello"`, the field value.
- `mp.mjs key Enter --port N` presses Enter in the focused field.
- `mp.mjs shot <path>.png --port N`, then read the image.
- `mp.mjs resize 375 812 --port N` prints `scrollWidth=375` when the page has no horizontal scroll.
- `mp.mjs query 'Transaction.count'` reads the stored count.

## Gotchas

- Recent and its `<count> this month` follow the database. The spent total, breakdown, and daily bars are still static markup.
- Typing in the composer field renders the preview through `GET /voucher`. Wait on the frame text before a `shot`.
