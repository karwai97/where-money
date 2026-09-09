# 04 — Filling a blank is not a correction

**What to build:** A currency chosen into a field the Model left empty does not
count against the Model's accuracy. Correcting one the Model actually read
still does.

Corrected Fields are the project's only real measure of extraction accuracy,
and they measure the Model. When the Extraction's currency was empty the Model
made no claim, so choosing one is the user filling a blank rather than the
Model getting it wrong — and counting it understates accuracy for a field the
Model never answered.

`ReviewBloc` records at the start of a Review whether the Extraction's currency
was empty, and skips the currency tally when it was. One field, one condition.
Do not generalise this into a list of app-prefilled fields; the problem exists
once.

**Blocked by:** 03.

**Status:** done

- [x] A currency chosen into a field the Model left empty is not a Corrected
      Field
- [x] A currency changed from one the Model read is a Corrected Field
- [x] Every other field's tally is unaffected
- [x] An edit of a committed Expense still carries its existing Corrected
      Fields forward
