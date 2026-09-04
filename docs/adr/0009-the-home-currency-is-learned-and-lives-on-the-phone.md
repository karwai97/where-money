---
status: accepted
---

# The Home Currency is learned from the first Expense and lives on the phone

ADR-0006 settled that there is one Home Currency and that everything else is
stored faithfully and left out of aggregation. It did not say where that
currency comes from. Until now it was a compiled constant, and its own comment
admitted why: there was no settings screen, so it was one constant in one
place.

Two decisions replace it.

**A Ledger has no Home Currency until its first Expense, and takes that
Expense's currency.** The alternatives were a compiled default, the device
locale, and asking on first launch. A compiled default is a build-time decision
about someone else's money. The device locale misfires exactly where it
matters — a Malaysian user on an `en_US` phone gets USD and an empty Rollup
every month until they notice something is wrong. Asking on first launch is an
interrogation before the user has seen anything worth answering for. Learning
it from the first receipt puts the decision where the evidence is, and the
Settings row afterwards says where it came from and lets it be changed.

The cost is real and worth writing down: the first Review a user ever runs has
no Home Currency and no past Expense to learn from, so its currency field is
empty and raises `NoCurrency`. That is the one case a compiled default would
have served. It happens once per Ledger, and the alternative is asserting a
currency the app has not earned.

**It is stored in the phone's preferences, beside the theme and the language.**
This contradicts the reason the glossary gives for what a Setting is — a fact
about this device rather than about the money — and the Home Currency is a fact
about the money. It is the axis every Rollup, chart and Recap is computed on.
Restore a Ledger onto a new phone and the theme resetting is harmless; the Home
Currency resetting would silently re-slice every month.

It belongs on the account, in Firestore, with the Ledger it describes. It is
not there because the device preference store already exists, is already read
before the first frame, and already has theme and language in it, while the
account has no such document and adding one is a schema change and a migration.
That work is deferred, not dismissed. Anyone moving it later should expect a
migration for users who set one before the move.

Nothing here reopens ADR-0006. One Home Currency, foreign Expenses stored and
excluded with the exclusion shown: all still true. Only where the one comes
from has changed.
