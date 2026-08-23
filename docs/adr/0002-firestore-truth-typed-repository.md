---
status: accepted
---

# Firestore is the source of truth, behind a hand-written typed repository

Firestore is the Ledger's store, chosen for durability across reinstalls
without building a sync layer. On its own that would delete the local data
modeling this project is meant to demonstrate, and would leave untyped
documents leaking through the whole app. So nothing above the repository ever
sees a `Map<String, dynamic>`: the prototype's `Expense`, `Extraction` and
`Rollup` types are the only currency above that seam, and the repository is the
sole place Firestore's shape is known.

## Consequences

- The Ledger is laid out flat as `users/{uid}/expenses/{id}`. Rollups are
  computed on device in pure Dart rather than denormalised into Firestore, so
  there is exactly one truth and `rollup.dart` survives from the prototype
  unchanged.
- Spending data leaves the device. The privacy claim is therefore about images
  (device-local) and not about amounts.
- Firestore's offline cache is the offline story for the Ledger; it is not a
  second source of truth.
