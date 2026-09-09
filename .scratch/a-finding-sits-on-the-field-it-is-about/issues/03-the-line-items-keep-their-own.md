# 03 — The Line Items keep their own

**What to build:** Someone whose rows do not add up reads that with the rows,
under the Line Items heading, rather than against a field somewhere else.

`LineItemsDoNotMatch`, `LineArithmeticOff` and `UnknownItemCategory` all name
the section rather than a field, and the section is a heading with rows under
it. Put them between the heading and the first row.

**Do not attach them to individual rows.** `LineItemsDoNotMatch` compares the
sum of every row against the subtotal, so no row owns it. The other two carry a
description but no index, so there is nothing to match a row on without
changing the domain package — and that change belongs in its own ticket,
decided on its own merits, not smuggled in here.

**Blocked by:** 01.

**Status:** done

- [x] The three Findings render under the Line Items heading
- [x] They are not repeated on any row
- [x] Removing the offending row clears the Finding
- [x] All three read in Chinese
