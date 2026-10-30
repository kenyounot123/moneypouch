# Download CSV

## Sub-features

- Settings, Your data, "Download CSV": `GET /transactions/download.csv` sends every kept transaction of the signed-in user, newest first, as `moneypouch-<date>.csv`.
- Columns: `Date` (ISO), `Name`, `Amount` (signed, `-11.25`), `Category`, `Transfer` (`yes` or blank), `Excluded` (`yes` or blank), `Note`, `Bank account`.
- Import reads the file back into another account: date, name, amount, category, transfer, excluded, and note (line breaks kept) survive. Import never reads `Bank account`. The CSV does not say whether a category is spending or income: a name matching one of the user's categories takes that kind, a new word used only on money in becomes an income category, and money in with no category lands in `Income`. Imported into the same account it adds nothing, since every row is already here (see [import.md](import.md)).

## How to get to it (user POV)

Sidebar, Settings. Your data sits under Keyboard and above Account. Bank sync is in the right-hand column from `xl`.

## Driving it with mp.mjs

- Headless Chrome saves downloads nowhere visible, so read the file through the link's URL: `mp.mjs js 'fetch(document.querySelector("a[href$=\"download.csv\"]").href).then(r => r.text())' --port N` on `/settings`. Add `r.headers.get("content-disposition")` for the filename. `js` prints the text as one JSON string, so parse it before counting rows.
