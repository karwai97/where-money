# 01 — A Finding goes under its field

**What to build:** Someone correcting a receipt sees each complaint under the
field it is about, and the form starts at the top of the screen instead of
below a card.

`Finding.field` has carried a `ReviewField` since the Check was written and the
screen has never read it. Group the Check's Findings by that field, and give
every input a slot below it for the ones that named it. The pinned card goes.

Keep the card's row as the presentation, moved: the severity icon, the label,
the detail. Do not reach for `InputDecoration.errorText` — `sayingFor` returns
a *(label, detail)* pair, `errorText` is one string, and the total field can
hold `NoTotal` and `TotalDoesNotAddUp` at once.

Findings with a null field stay where they are until ticket 02. Findings naming
`ReviewField.lineItems` are ticket 03. This is the fields with their own input:
merchant, date, currency, category, payment method, and the four amounts.

**Blocked by:** None — can start immediately.

**Status:** done

- [x] Nothing is pinned between the app bar and the form
- [x] Each Finding naming a field renders directly under that field's input
- [x] A field holding two Findings shows both
- [x] `warn` and `fail` stay visually distinct
- [x] Correcting a field clears its Finding on the next keystroke
- [x] Every Finding still reads in Chinese in its new position
- [x] The commit button is still enabled with a `fail` standing
