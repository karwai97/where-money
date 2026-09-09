# 05 — The Model is asked for a code

**What to build:** Receipts stop coming back as `RM` or `$` in the first place.
The Worker's response schema pins `currency` to an ISO 4217 enum, the way
`category` is already pinned.

This is the actual fix. The alias map in ticket 02 is a shim for what is
already stored; this stops new Extractions needing one.

**Deliberately separate.** The Worker is its own deploy. Doing this inside the
app change would leave the app wrong until both shipped, and in the wrong order
it would be wrong for longer. The app must behave correctly whether or not this
has landed, which is why nothing here blocks it and it blocks nothing — but do
not land it before ticket 02 is in the app.

The alias map is not deleted afterwards. The Ledger holds Expenses with `RM`
and `???` in them, and those still have to be shown.

**Blocked by:** None — can start immediately.

**Status:** done

- [x] The Worker's schema pins `currency` to an ISO 4217 enum
- [x] The wire test covers the new shape
- [x] The app behaves correctly against both the old and the new Worker
