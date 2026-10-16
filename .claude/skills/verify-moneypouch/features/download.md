# Download CSV

## Sub-features

- Settings, Your data, "Download CSV": `GET /transactions/download.csv` sends every kept transaction of the signed-in user, newest first, as `moneypouch-<date>.csv`.
- Columns: `Date` (ISO), `Name`, `Amount` (signed, `-11.25`), `Category`, `Transfer` (`yes` or blank), `Excluded` (`yes` or blank), `Note`, `Bank account`.
- Import reads the file back into another account: date, name, amount, category, excluded, and note survive. Import has no Transfer column and squishes a note to one line.

## How to get to it (user POV)

Sidebar, Settings. Your data sits between Bank sync and Account.

## Driving it with mp.mjs

- Headless Chrome saves downloads nowhere visible, so read the file through the link's URL: `mp.mjs js 'fetch(document.querySelector("a[href$=\"download.csv\"]").href).then(r => r.text())' --port N` on `/settings`.
