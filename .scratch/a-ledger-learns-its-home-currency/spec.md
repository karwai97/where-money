# A Ledger learns its Home Currency

**Status:** done. Issue 05, the separate Worker deploy, has landed too — it
needs `npx wrangler deploy` to reach the model.

## Problem Statement

Currency is a free-text field sitting between two closed dropdowns. Category
and Payment Method are chosen; currency is typed, into a field that will take
anything.

The Check does not catch what gets typed, because it does not check currencies.
It checks string length: `currency.length != 3`. So `$` and `RM` raise a
Finding, and `XYZ` raises nothing. Nor does `???` — which is what
`Expense.fromExtraction` writes when the Model read no currency at all. A `???`
Expense is stored, is excluded from every Rollup for not being the Home
Currency, and is invisible to the Check that should have caught it. Reopening
it to correct something shows `???` in the field with nothing said about it.

Underneath that, the Home Currency is a compiled constant. Its own comment says
why: there is no settings screen, so it is one constant in one place. The
consequence is that a Ledger's aggregation axis is a decision made at build
time by whoever wrote `MYR` into the source.

And when nothing is detected from a receipt, the field is simply empty. The
user is left to know what they paid in.

## Solution

Currency becomes a choice from a closed set of ISO 4217 codes, made in a sheet
with a search, whose first rows are the currencies this Ledger has already
seen.

The Home Currency stops being compiled in. A Ledger has none until its first
Expense is committed, and takes that Expense's currency. From then on it is the
user's, visible and changeable in Settings, and it is what the currency field
is seeded with whenever a receipt yielded nothing.

The Check learns what a currency actually is, so `XYZ` and `???` stop passing
silently.

## User Stories

1. As someone recording an expense, I want to pick a currency from a list, so
   that I cannot commit a typo into my Ledger.
2. As someone whose receipt was read cleanly, I want the currency it was read
   in already selected, so that I confirm rather than retype.
3. As someone whose receipt yielded no currency, I want my Home Currency
   already selected, so that the ordinary case costs me no taps.
4. As someone who spends in a handful of currencies, I want the ones I have
   used before at the top of the list, so that I am not searching a list of a
   hundred and eighty for the one I used last week.
5. As someone looking for an unfamiliar currency, I want to search the list, so
   that I do not scroll to find it.
6. As someone on a phone, I want the picker to take the screen rather than drop
   a small window over the form, so that it does not fight the keyboard.
7. As someone whose receipt printed `RM`, I want the field to show `MYR`, so
   that the app understands a symbol I did not have to translate.
8. As someone whose receipt printed `$`, I want to be told the app does not
   know which currency that is, so that it does not guess between eight of
   them.
9. As someone opening an old Expense stored as `???`, I want to see `???` and
   be told it is not a currency, so that I can fix it rather than have it
   silently rewritten.
10. As someone opening an old Expense in a foreign currency, I want it to still
    be in that currency when I close it, so that correcting a typo does not
    move it into a different month's total.
11. As a new user with an empty Ledger, I want no currency assumed on my
    behalf, so that the app does not quietly decide what my money is.
12. As a new user, I want my first committed Expense to set my Home Currency,
    so that I never have to find a settings screen to make totals work.
13. As a new user with no Home Currency yet, I want the Ledger to say so rather
    than show empty charts, so that I know why there are no totals.
14. As someone whose Home Currency is set, I want to see it in Settings and
    know it came from my first expense, so that it is not a value I have to
    guess the origin of.
15. As someone who moved country, I want to change my Home Currency, so that my
    totals follow me.
16. As someone changing it, I want to be told in the Settings row what it
    governs, so that I understand my charts are about to be recomputed.
17. As someone changing it, I do not want a confirmation dialog, so that the
    app keeps saying things in place rather than in modals.
18. As someone correcting the currency on a receipt the Model got wrong, I want
    that counted as a correction, so that the accuracy measure stays honest.
19. As someone picking a currency into a field the Model left empty, I do not
    want it counted as a correction, so that the accuracy measure is not
    charged for a blank the Model never filled.
20. As someone reading the app in Chinese, I want the picker and the Settings
    row to read in Chinese, so that nothing falls back to English.
21. As someone reading currency codes, I want to see the code alone, so that
    the list reads the same in every language and matches what is on my
    receipt.
22. As someone whose receipt was read as `XYZ`, I want the Check to say that is
    not a currency, so that it does not reach my Ledger unremarked.

## Implementation Decisions

**The currency set.** The ISO 4217 codes go into the domain package alongside
the existing closed sets. Currency differs from Category in why it earns an
ADR, not in how it is closed: issue 05 sends both to the Model as an enum, and
ADR-0005 exists because this project decided the Category taxonomy's
membership. Nobody decided ISO 4217's, so it earns no ADR and no glossary
entry — it is a fact about the world, not a taxonomy this project invented.

**No copy for currency codes.** A code is already the word, in every language.
Currency codes are deliberately outside the invariant
`test/what_the_domain_is_called_test.dart` enforces — that every slug in a
closed set has copy in both languages. That test exists because
`personal_care` printed raw is a bug; `MYR` printed raw is correct. Extending
it to currencies would demand roughly three hundred and sixty hand-written ARB
entries to render what the receipt already prints.

**The picker.** A read-only field opening a full-height modal sheet with a
search field. Not a `DropdownMenu`: a hundred and eighty rows in an overlay is
a small scrolling window that fights the keyboard, which is the problem the
sibling feature exists to fix. The sheet's head is the Home Currency followed
by the distinct currencies already in the Ledger, most recent first, then the
full set. Search matches codes.

**Where the head comes from.** The sheet reads `LedgerBloc` through the context
when it opens. `LedgerBloc` and `ReviewBloc` are siblings above the Navigator
and both Review routes are already under them, so nothing is rewired.
`ReviewBloc` does not become a second subscriber to the Ledger stream: the used
set decides row order in a picker, which is presentation, not domain state.

**Aliases.** A small map in the domain package rewrites unambiguous symbols to
their code — `RM`, `S$`, `HK$`, `NT$`, `£`, `€`. Ambiguous ones are excluded on
purpose: `$` is eight currencies and `¥` is two. It is applied when Review
seeds its form, not in `Extraction.fromJson`. An Extraction is what the Model
claims it read, and the Corrected Field tally is built on that claim being
intact; rewriting it at parse time would make the accuracy measure describe
something the Model never said.

**Unaliasable values.** Anything that survives aliasing without being an ISO
code — `$`, `XYZ`, a stored `???` — is shown as selected and invalid, with the
Finding beside it. It is not silently replaced. Falling back to the Home
Currency would convert a committed foreign Expense into a home one the moment
the user opened it to fix a typo, moving it into a different month's total from
an edit they did not make.

**The Check.** `currency.length != 3` becomes a membership test against the ISO
set. `NoCurrency` survives for the genuinely empty case, which the null Home
Currency makes routine rather than theoretical; `CurrencyNotAnIsoCode` gains
real teeth and starts firing on `XYZ` and `???`.

**Home Currency is learned.** None until the first Expense is committed; that
Expense's currency sets it. Not derived from the device locale — a Malaysian
user on an `en_US` phone would get USD and an empty Rollup every month until
they noticed. Not asked for on first launch. Not compiled in.

**While there is none**, `LedgerBloc` emits a state carrying no Rollup and the
Ledger screen shows an empty state instead of charts. `Rollup.forMonth` keeps
its non-nullable `homeCurrency`. Having none is a phase of the interface, not a
shape of the domain, and making the domain nullable would grow a null branch in
every reader — the Rollup, the prompt, the hash, the charts, the foreign-
currency notice on an Expense — for a state that ends at the first commit.

**Where it is stored.** In the phone's preferences beside the theme and the
language, and read before the first frame the same way. This contradicts the
glossary's reason for what a Setting is — a fact about this device rather than
about the money — and Home Currency is a fact about the money. ADR-0009
records that, and records that the account is where it eventually belongs.

**Seeding.** The Home Currency seeds the field for an Expense typed by hand and
for a Scan that yielded no currency. It does not seed an edit: opening a
committed Expense shows what is stored, `???` included.

**Corrected Fields.** `ReviewBloc` records at the start of a Review whether the
Extraction's currency was empty, and skips the currency tally when it was. The
Model made no claim about a blank, so filling it is not a correction of the
Model. This is why the seed writes into the Extraction rather than only into
the widget: with a Home Currency set, the Check sees it and stays quiet; with
none, the field stays empty and `NoCurrency` fires, which is exactly what the
first-ever Review should say.

**Changing it later.** Freely changeable in Settings. No confirmation dialog —
the house style says things in place. The row carries a line saying what the
setting governs: totals and Recaps are computed in it, and spending in other
currencies is listed but not counted. Cached Recaps need no special handling:
`rollupHash` already hashes the currency, so changing it re-keys every month
correctly.

## Testing Decisions

A good test asserts what the user can read and choose. Widget types are for
reaching a control, never for an assertion. Currency codes appear in
assertions as the strings a user sees, not as constants pulled from the set
under test.

**The seam is `WhereMoneyApp`**, pumped whole with the in-memory fakes, as in
`test/review/review_screen_test.dart`, `test/ledger/living_with_the_ledger_test.dart`
and `test/scan/scan_to_expense_test.dart`. Almost everything is reachable
there: the sheet opening and its head order, `RM` arriving from
`FakeModelGateway` and showing as `MYR`, `XYZ` showing as invalid, the empty
state before a Home Currency exists, charts appearing after the first commit,
the Settings row changing it, and the Corrected Fields read back off
`InMemoryLedgerStore` after a commit.

`InMemoryDevicePreferences` gains a Home Currency, which extends a fake rather
than adding a seam. `test/data/device_preferences_test.dart` covers the stored
implementation the way it covers theme and language.

**Two existing pure seams take the rest.** `packages/core/test/check_test.dart`
for the membership test, including that `XYZ` and `???` now raise
`CurrencyNotAnIsoCode` and empty still raises `NoCurrency`.
`packages/core/test/taxonomy_test.dart` for the set and the alias map as data:
every alias target is in the set, and no ambiguous symbol is a key.

`test/review/review_bloc_test.dart` is the fallback for the Corrected Fields
suppression only if it proves awkward to observe from the top. Prefer the top.

The Chinese guards — `test/review/review_speaks_chinese_test.dart` and
`test/ledger/the_ledger_speaks_chinese_test.dart` — extend to the sheet's
chrome, the Settings row and the no-Home-Currency empty state. The codes
themselves are not translated and must not be asserted as though they were.

## Out of Scope

- Pinning the Worker's schema to an ISO enum. It is issue 05 here and is
  deliberately not part of this change: the Worker is a separate deploy, and
  coupling the app to it means the app is wrong until both ship. The alias map
  is needed regardless, for the Expenses already stored.
- Any exchange rate, conversion or multi-currency total. ADR-0006 stands
  unchanged: one Home Currency, everything else stored faithfully and excluded
  from aggregation with the exclusion shown.
- Moving the Home Currency to the account in Firestore. Acknowledged in
  ADR-0009 as where it belongs; not done here.
- Currency names or symbols in the picker.
- Migrating the `???` Expenses already in the Ledger. They become visible and
  correctable, which is enough.
- Anything about the Findings overlay. That is
  `.scratch/a-finding-sits-on-the-field-it-is-about/`, which lands separately.

## Further Notes

The two features are independent and neither blocks the other. They do touch
the same file, so landing one and then rebasing the other is easier than
landing them together.

`Expense.fromExtraction`'s `???` is not removed. Once the Home Currency seeds
the field it becomes hard to reach for new Expenses, but it is what the Ledger
already holds and what an Expense restored from Firestore can still carry, so
it stays a value the app can show and the Check can complain about.

The first Review a user ever runs has no Home Currency and no past Expense to
learn from, so it shows an empty currency field with `NoCurrency` under it.
That is the deliberate consequence of not asserting a default the app has not
earned, and it happens exactly once per Ledger.
