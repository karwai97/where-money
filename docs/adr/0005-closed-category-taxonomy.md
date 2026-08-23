---
status: accepted
---

# The Category taxonomy is closed and not user-editable

The 18 Categories are sent to the Model as a JSON Schema `enum`, which is what
makes the returned category a guaranteed member of a known set rather than free
text the app has to interpret. User-defined categories would mean building the
schema from user input at request time, which cannot be validated ahead of
time and defeats the enum check in `receipt_check.dart`. A parallel set of
user-defined categories was also rejected: it creates two taxonomies that every
chart and every Recap would have to reconcile.

This is a deliberate deviation from what expense trackers normally ship, so
expect it to be questioned.
