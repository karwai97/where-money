# A Finding sits on the field it is about

**Status:** done

## Problem Statement

Review pins everything the Check noticed to the top of the screen, outside the
scroll view, above the fields. On a phone with the keyboard up, that card and
the receipt above it leave a strip of form to type into. The card was put there
on purpose — the comment in `review_screen.dart` says it is so a Finding does
not scroll away while the user corrects it — but the cost lands on the one
thing Review exists to do.

It gets worse while typing. `Check.of` re-runs on every keystroke, so the card
grows and shrinks as Findings appear and clear, and the fields under it move
while the user's finger is on them.

And the card says a thing about a field from a distance. "The date is in the
future" sits at the top of the screen; the date field is somewhere below it.
The user has to carry the sentence down to the field it is about.

## Solution

Every Finding that names a field is shown under that field. `Finding.field`
already exists and already carries a `ReviewField` — the screen has simply
never read it. The correction and the reason for it end up in the same place,
and the form starts at the top of the screen where a form should.

Two Findings name no field, and they are handled separately rather than left in
a shrunken version of the same card.

## User Stories

1. As someone correcting a receipt on a phone, I want the fields to start at
   the top of the form, so that the keyboard does not leave me a strip to type
   into.
2. As someone correcting a receipt, I want the reason a field is wrong to sit
   under that field, so that I do not have to carry a sentence from the top of
   the screen down to the thing it describes.
3. As someone correcting a date the Check called impossible, I want the
   complaint attached to the date field, so that tapping the calendar and
   reading the complaint are the same gesture.
4. As someone typing into a form, I want the fields to stay where they are, so
   that a Finding clearing itself two fields above does not move the field
   under my finger.
5. As someone who has just fixed a total, I want the Finding about it to
   disappear from under the total, so that I can see I have finished.
6. As someone looking at a field with two things wrong with it, I want to see
   both, so that fixing one does not hide the other.
7. As someone reading a `fail`, I want it to look different from a `warn`, so
   that I can tell arithmetic that does not add up from something merely
   unusual.
8. As someone who photographed something that is not a receipt, I want to be
   told that about the whole photo rather than about a field, so that I do not
   go looking for which field to fix.
9. As someone whose receipt the Model asked a human to look at, I want that
   said once at the top of the form, so that it does not take height from every
   screen after it.
10. As someone whose commit was refused, I want to be told at the top of the
    form with my typing still in the fields, so that I can retry without
    retyping.
11. As someone whose receipt came back clean, I want one line saying so, so
    that a form with nothing wrong still asks for my confirmation rather than
    looking unfinished.
12. As someone whose line items do not add up to the subtotal, I want that said
    under the Line Items heading, so that it is against the rows it is about
    rather than against a field.
13. As someone with a line whose quantity times price does not match its
    amount, I want that said with the Line Items, so that I know which section
    to look through.
14. As someone reviewing a Scan on a wide screen, I want the receipt beside the
    form as it is now, so that this change costs me nothing I already had.
15. As someone reading the app in Chinese, I want every Finding to read in
    Chinese wherever it has moved to, so that nothing falls back to English on
    its way to a field.
16. As someone committing an Expense the Check disagrees with, I want the
    button to stay enabled, so that a discount the Check cannot see does not
    stop me recording what I actually paid.
17. As someone correcting an Expense a week after committing it, I want the
    same treatment on the same screen, so that Review does not behave one way
    for a Scan and another for a correction.

## Implementation Decisions

- The pinned card is removed. Nothing sits between the app bar and the receipt
  any more.
- Findings are dispatched by `Finding.field`. Each `ReviewField` collects the
  Findings naming it and renders them directly beneath its input.
- The inline presentation is a widget of the project's own, not
  `InputDecoration.errorText`. `sayingFor` returns a *(label, detail)* pair and
  `errorText` is one string; flattening the pair loses the shape the copy was
  written in. It also cannot show two Findings, and `total` takes `NoTotal` and
  `TotalDoesNotAddUp` together.
- `warn` and `fail` keep the icon and colour treatment the card already used,
  so the severities stay distinguishable after the move.
- `NotAReceipt` gets a full-width banner above the form. `Check.of`
  short-circuits and returns it alone, so it never shares the screen with
  anything.
- `ModelAskedForReview`, the refusal notice and the clean-Extraction line move
  into the top of the scroll view and scroll away with the form. None is about
  a field and none is worth permanent height.
- The three Findings naming `ReviewField.lineItems` render as a group under the
  Line Items heading. `LineItemsDoNotMatch` is about the set of rows against
  the subtotal and no single row owns it.
- `LineArithmeticOff` and `UnknownItemCategory` carry a `description` but no
  index, so they cannot be attached to a row. Adding an index to them is a
  change to the domain package, and it is not made here.
- The commit button's behaviour is unchanged. A `fail` does not disable it. The
  Check costs nothing and calls nothing, and it is not an authority.
- No copy changes. `sayingFor` and every ARB key it reads stay as they are.
  This moves where the sentences appear, not what they say.

## Testing Decisions

A good test here asserts what a user can read and where they can read it, not
which widget class was used. Reaching a widget by type is for typing into a
field, never for an assertion.

The seam is `WhereMoneyApp`, pumped whole with the in-memory fakes, as in
`test/review/review_screen_test.dart` and
`test/review/reviewing_a_scan_test.dart`. Those files already open Review from
both the Ledger and the Inbox and drive it by label; the new tests extend them
rather than starting a new harness.

What gets pinned:

- A Finding's sentence appears below its field and above the next one.
- Correcting the field removes the sentence.
- A field with two Findings shows both.
- `NotAReceipt` renders as the banner, with nothing else on screen beside it.
- The refusal, the clean line and `ModelAskedForReview` scroll with the form.
- The three Line Items Findings appear with the Line Items, not with a field.
- The commit button is enabled with a `fail` standing.

`test/review/what_a_finding_says_test.dart` already pins the English sentence
for every `Finding` and needs no change — it tests the copy, and the copy is
not moving. `test/review/a_finding_in_chinese_test.dart` and
`test/review/review_speaks_chinese_test.dart` are the guard that nothing falls
back to English on the way to its new position; extend those rather than
writing a third Chinese file.

## Out of Scope

- Gating the commit button on severity. Considered and rejected: the Check
  warns about receipts that are legitimately unbalanced, and blocking a commit
  over it would make the Check an authority it was built not to be. If it is
  wanted later, a count beside the button that scrolls to the first Finding is
  the version that does not take the decision away.
- Giving `LineArithmeticOff` and `UnknownItemCategory` an index so they can be
  attached to a row. Worth doing on its own merits, not inside a UI pass.
- Any change to the currency field. That is
  `.scratch/a-ledger-learns-its-home-currency/`, which lands separately and
  does not block this.
- Where the receipt sits relative to the form.

## Further Notes

There are exactly two field-less Findings: `NotAReceipt` and
`ModelAskedForReview`. Every other member of the sealed set names a field. A
new Finding added with a null field lands in the scrolling group by default,
which is the safe place for it.

The two features in `.scratch/` are independent. Either can land first.
