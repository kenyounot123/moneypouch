# Overview

## Sub-features

- Composer at the top, an input labelled "Quick add", with the preview frame `turbo-frame#voucher` under it. See [composer.md](composer.md).
- Spent total, category breakdown, daily bars, and Recent: the 5 latest kept transactions and the count of this month's.
- Sidebar with navigation and the theme switch.

## How to get to it (user POV)

Sign in. `/` is the Overview.

## Driving it with mp.mjs

- `mp.mjs type '[aria-label="Quick add"]' hello --port N` prints `"hello"`, the field value.
- `mp.mjs key Enter --port N` presses Enter in the focused field.
- `mp.mjs shot <path>.png --port N`, then read the image.
- `mp.mjs resize 375 812 --port N` prints `scrollWidth=375` when the page has no horizontal scroll.
- `mp.mjs query 'Transaction.count'` reads the stored count.

## Gotchas

- Recent and its `<count> this month` follow the database. The spent total, breakdown, and daily bars are still static markup.
- Typing in the composer field renders the preview through `GET /voucher`. Wait on the frame text before a `shot`.
