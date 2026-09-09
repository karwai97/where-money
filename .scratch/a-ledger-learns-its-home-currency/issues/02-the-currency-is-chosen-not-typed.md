# 02 — The currency is chosen, not typed

**What to build:** Someone recording an expense picks a currency from a list
instead of typing one. The list opens with the currencies this Ledger already
uses, and can be searched for anything else. A receipt printed in `RM` arrives
as `MYR` without the user translating it.

Replace the free-text field with a read-only one that opens a full-height sheet
carrying a search field.

**Not a `DropdownMenu`.** A hundred and eighty rows in an overlay is a small
scrolling window that fights the keyboard, which is the complaint this whole
effort answers. A sheet owns the screen and has room for a head.

The head is the Home Currency, then the distinct currencies already in the
Ledger, most recent first, then the full set. Read the Ledger from `LedgerBloc`
through the context when the sheet opens — it is a sibling of `ReviewBloc`
above the Navigator and both Review routes are already under it. **Do not make
`ReviewBloc` a second subscriber to the Ledger stream**: this decides row order
in a picker, which is presentation, not domain state.

Add a small alias map to the domain package turning what receipts actually
print into a code. Unambiguous symbols only: `RM`, `S$`, `HK$`, `NT$`, `£`,
`€`. **`$` and `¥` are not keys** — `$` is eight currencies and `¥` is two, and
guessing between them is worse than saying the app does not know. Apply it when
Review seeds its form, **not in `Extraction.fromJson`**: an Extraction is what
the Model claims it read, and the Corrected Field tally is built on that claim
staying intact.

A value that survives aliasing without being an ISO code — `$`, `XYZ`, a stored
`???` — shows as selected and invalid, with its Finding beside it. **Do not
fall back to another value.** The existing closed-field widget quietly falls
back to its last option, which is tolerable for a Category because `other` is a
real answer; for a currency it would invent one. Falling back to the Home
Currency would be worse still: it would move a committed foreign Expense into a
different month's total the moment the user opened it to fix a typo.

Rows show the code alone.

**Blocked by:** 01.

**Status:** done

- [x] The currency field cannot be typed into
- [x] The sheet lists the Home Currency and previously used currencies first,
      then the rest
- [x] Search finds a currency by code
- [x] A receipt read as `RM` shows `MYR`
- [x] `$`, `XYZ` and `???` show as themselves, invalid, with the Finding beside
      them
- [x] Opening a committed foreign Expense and closing it leaves its currency
      unchanged
- [x] No ambiguous symbol is an alias key, and every alias target is in the set
- [x] The sheet's chrome reads in Chinese; the codes are not translated
