# 03 — A Ledger learns its Home Currency

**What to build:** A new user's Ledger has no Home Currency, says so instead of
showing empty charts, and takes one from the first Expense they commit. From
then on it is theirs: visible in Settings, changeable, and what the currency
field is seeded with whenever a receipt yielded nothing.

Delete the compiled `homeCurrency` constant.

**Read ADR-0009 before starting.** The Home Currency goes into the phone's
preferences beside the theme and the language, read before the first frame the
same way. This contradicts what the glossary says a Setting is — a fact about
this device rather than about the money — and the Home Currency is squarely a
fact about the money. The ADR records that trade-off and records that the
account is where it eventually belongs.

**While there is none**, emit a Ledger state carrying no Rollup and show an
empty state saying totals start with the first expense, rather than bars of
zero. **Leave `Rollup.forMonth` non-nullable.** Do not thread a nullable
currency through the domain: every reader would grow a null branch — the
Rollup, the prompt, the hash, the charts, the foreign-currency notice on an
Expense — for a state that ends at the first commit. Having none is a phase of
the interface, not a shape of the domain, and the domain should never see it.
No Recap is asked for while there is none, which falls out of there being no
Rollup to ask about.

The Settings row uses ticket 02's sheet, says the value was inferred from the
first expense, and changes it freely. **No confirmation dialog** — the house
style says things in place. One line under the row says what it governs: totals
and Recaps are computed in it, and spending in other currencies is listed but
not counted. Cached Recaps need nothing; `rollupHash` already hashes the
currency, so a change re-keys every month by itself.

Once set it seeds Review's currency field for an Expense typed by hand and for
a Scan that yielded no currency. **It does not seed an edit** — opening a
committed Expense shows what is stored, `???` included. The seed writes into
the Extraction rather than only into the widget, so the Check sees the seeded
value and stays quiet.

**Not derived from the device locale.** A Malaysian user on an `en_US` phone
would get USD and an empty Rollup every month until they noticed.

The first Review a user ever runs therefore has no Home Currency and no past
Expense to learn from, so its currency field is empty with `NoCurrency` under
it. That is the deliberate consequence of not asserting a default the app has
not earned, and it happens once per Ledger. **It is not a bug to fix by putting
the constant back.**

**Blocked by:** 02.

**Status:** done

- [x] The `homeCurrency` constant is gone
- [x] A Ledger with no Home Currency shows an empty state, not charts, and says
      why
- [x] No Recap is requested while there is none
- [x] `Rollup.forMonth` still takes a non-nullable currency, and nothing in the
      domain knows this state exists
- [x] Committing the first Expense sets the Home Currency to its currency, and
      charts appear in it
- [x] The Settings row shows it, says it was inferred, and changes it with no
      dialog
- [x] Changing it recomputes the charts and re-keys the Recaps
- [x] It survives a restart
- [x] It seeds a hand-typed Expense and a Scan with no currency, but not an
      edit
- [x] The empty state and the Settings row read in Chinese
