# 01 — The Check knows what a currency is

**What to build:** Someone reviewing a receipt the Model read as `XYZ`, or
correcting an old Expense stored as `???`, is told that is not a currency.
Neither says anything today.

The Check does not check currencies. It checks string length:
`currency.length != 3`. So `$` and `RM` raise a Finding and `XYZ` does not —
and neither does `???`, which `Expense.fromExtraction` writes itself when the
Model read nothing. A `???` Expense is stored, excluded from every Rollup for
not being the Home Currency, and invisible to the pass that should have caught
it.

Put the ISO 4217 code set in the domain package beside the existing closed
sets, and make the Check test membership instead of length.

The set is codes only. **Do not add copy for them, and do not extend the test
that demands every slug in a closed set has words in both languages.** That
test is right to exist — `personal_care` printed raw is a bug. `MYR` printed
raw is correct: a code is already the word in every language, and it is what
the receipt prints. Extending the invariant would cost roughly three hundred
and sixty hand-written entries to render something the user can already read.

Keep both Findings. `NoCurrency` stays for the genuinely empty case, which is
about to become routine rather than theoretical once ticket 03 lands.

**Blocked by:** None — can start immediately.

**Status:** done

- [x] The ISO 4217 code set is in the domain package
- [x] A currency in the set raises nothing
- [x] `XYZ` raises `CurrencyNotAnIsoCode`, in Review and in a correction
- [x] `???` raises `CurrencyNotAnIsoCode`
- [x] `$` and `RM` still raise `CurrencyNotAnIsoCode`
- [x] Empty still raises `NoCurrency`
- [x] Lowercase is treated as its uppercase code rather than rejected
- [x] The test that demands copy for every slug is unchanged
- [x] The domain package still has no Flutter dependency
