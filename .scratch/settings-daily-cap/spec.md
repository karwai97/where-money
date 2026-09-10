# The daily cap on Settings — handoff for Option B

**Status:** ready-for-agent. Design canvas:
https://claude.ai/code/artifact/b0098709-0ae8-49dd-a2de-8b24d8ec12b1
(page "Option B": the artboards "Settings · Daily cap" and "Daily cap · States";
the page "Not chosen" holds A, C and D and nothing on it is being built).

## Overview

A user who hits the cap finds out in the Inbox, after the fact. Nothing on the
phone says how many Scans a day there are or how many are left. Settings gets
one new row under Home Currency: the day's spend against the cap as a figure,
a thin track under it, and a sentence saying what the number governs or, once
the cap is spent, when more Scans arrive.

Two things have to change before the row can be drawn honestly, and both are
in this spec: the Worker has to say how much of the allowance is used on
*every* answer rather than only when refusing, and the phone has to remember
what it last heard.

The row is a fact about the service rather than a Setting, and it is drawn
read-only: no cell fill, nothing answers a tap. It sits with the Settings all
the same because the sentence under it is the kind of thing this screen says.

## Where the numbers come from

Today the Worker reports `used`, `limit` and `resets_at` only in the
`cap_reached` refusal (`worker/src/index.ts`, `spendAllowance`). A 200 carries
nothing about the allowance. Two facts govern the design:

- `limit` on the wire is the cap the Worker *enforces*: the requested
  `Knobs.dailyCap` (40 by default) clamped under `DAILY_MODEL_CEILING`
  (20, a spend decision — see `where_money-handoff.md`). So the honest figure
  can only come from the Worker. Before it has ever answered on this phone the
  row shows the requested cap, and that number may drop once it does.
  Aligning the Remote Config value with the ceiling avoids the jump; that is
  an operator decision, noted here rather than made here.
- Days roll over at `startOfNextDay` in UTC (`worker/src/allowance.ts`), so
  the reset lands at 08:00 in Malaysia. `resets_at` is the only clock that
  counts; the phone never works out midnight for itself. The counter is also
  approximate by design (KV replication), and the copy never says "exactly".

Scans and Recaps are counted separately under the same ceiling. This row is
about Scans only; the `recaps` counter is not shown.

## Layout

One column, scrolling, 390px reference. The order, top to bottom:

1. App bar
2. Theme
3. Language
4. Lock Where Money
5. Home Currency
6. **Daily cap** — new
7. The 24px gap
8. Sign out

The new row is a `Ruled` like the four above it and is the last thing before
the gap. Nothing else on the screen moves.

## Design tokens used

Every value is a role on the theme or a helper in `lib/settings/themes.dart`.
Hex is dark / light, for checking against the canvas.

| Token | Dark / light | Used for |
| --- | --- | --- |
| `colorScheme.onSurface` | `#E5E6EB` / `#17181C` | the figure |
| `colorScheme.onSurfaceVariant` | `#9A9DA8` / `#5A5E68` | the word beside the figure, the sentence (`bodySmall` carries it) |
| `colorScheme.outline` | `#7E8290` / `#62666F` | the label mark |
| `colorScheme.outlineVariant` | `#262931` / `#E3E5EA` | the hairline under the row |
| `colorScheme.surfaceContainerHighest` | `#2E323C` / `#D9DBE2` | the track's empty part |
| `colorScheme.primary` | `#9B8CF0` / `#5B47C4` | the track's filled part |
| `asAMark(theme)` | 11px / 600 / tracking 1.4, upper case | label "Daily cap" |
| `asFigures(bodyMedium w500, letterSpacing 0.4)` | JetBrains Mono 14px / 500 | `12 / 40` and `40` — the same style `Chosen` draws the currency code in |
| `bodySmall` | 12px, muted | the word beside the figure, the sentence under |

Spacing, all already named in `lib/a_form_of_rows.dart` and read from there:
label column `labelWidth`, label-to-value `labelGap` (16), the indent under
the row `sayingIndent`, row padding 16 / 7, row minimum height 52. New values,
the only ones this spec introduces: the value column is a `Column` with 8px
between the figure line and the track; the figure line has 6px between the
figure and the word; the track is 3px tall with a 2px radius and fills the
value column's width; the figure line sits at the row's usual 8px vertical
padding so it aligns with the cells above it.

## Components

| Element | Built from | Notes |
| --- | --- | --- |
| Row | `Ruled` holding a `Column`: the label-and-value pair, then the sentence | Composed by hand like `_Lock`, not through `asARow`: there is no field here and no cell. `inTheLabelColumn(context, words.settingsDailyCap)` for the mark. |
| Figure | `Text` in `asFigures(bodyMedium w500, letterSpacing 0.4)` | Formatted in code as `'$used / $cap'`, or `'$cap'` before the Worker has spoken. Not an ARB string: the figure is language-neutral on purpose, the way `Head`'s trailing count is. |
| Word beside the figure | `Text` in `bodySmall`, 6px after the figure, baseline-aligned | `settingsDailyCapScansToday` "Scans today" once counted; `settingsDailyCapScansADay` "Scans a day" before. Two keys, not one with a placeholder, so Chinese can put the count where it belongs. |
| Track | Two `Container`s, or `LinearProgressIndicator` with `minHeight: 3` and the two colours above | Hidden (not drawn, no height held) in the not-counted state. Fill is `used / cap` clamped to 1. |
| Sentence | `Text` in `bodySmall` at `sayingIndent`, 0px under the value column (the column's own 8px bottom padding is the gap) | Which sentence: see states. |

## States and interactions

The row never answers a tap. `settingsDailyCap` is the label key, "Daily cap".

| State | Figure | Word | Track | Sentence |
| --- | --- | --- | --- | --- |
| Not counted yet — nothing remembered for this account on this phone | `Knobs.dailyCap` | "Scans a day" | none | `settingsDailyCapGoverns` |
| Nothing spent today — a remembered allowance whose `resetsAt` is in the past | `0 / limit` | "Scans today" | empty | `settingsDailyCapGoverns` |
| Part spent | `used / limit` | "Scans today" | `used / limit` filled | `settingsDailyCapGoverns` |
| Spent, reset time known | `limit / limit` | "Scans today" | full | `inboxCapped` then `inboxMoreScansAt(asMoment(words, resetsAt))`, one line, space between |
| Spent, no reset time | `limit / limit` | "Scans today" | full | `inboxCapped` then `inboxMoreScansTomorrow` |

The "Spent, no reset time" row above is unreachable and was not built: ticket 2
makes `Allowance.resetsAt` required, so a remembered allowance always has one
and `inboxMoreScansTomorrow` never comes up on this screen. The Inbox still
says it, from `AllowanceSpent.resetsAt`, which can be null.

`settingsDailyCapGoverns` is new: "How many receipts the Model reads for you
in one day. When they are spent, new photos wait in the Inbox until tomorrow."
The spent sentences reuse the Inbox's keys verbatim: same news, same words,
one definition (`on_screen.dart`'s rule).

The row is drawn from the first frame with whatever was remembered, the way
`_Lock` waits on its read: while the preference is being read the row shows
the not-counted state, and the value arrives in place. No spinner.

Nothing here is a failure state. A Worker that has stopped sending the
headers leaves the last remembered allowance in place until its `resetsAt`
passes, then the row reads "0 / limit" until the next answer. Acceptable, and
the counter was never exact.

## The plumbing

Four tickets' worth, in dependency order. Each is one file under
`issues/` when they are written.

1. **The Worker says how much is used on every answer.** Three response
   headers on both endpoints, on the 200 and on every refusal the allowance
   was checked for: `x-allowance-used`, `x-allowance-limit`,
   `x-allowance-resets-at` (ISO 8601). `reserve` already returns all three.
   The JSON body of `cap_reached` keeps its fields; nothing that reads them
   changes. Add the headers to the table in `worker/README.md`.
2. **The app hears it.** A new value in `packages/core`, `Allowance`
   (`used`, `limit`, `resetsAt`, all required; `resetsAt` a `DateTime`).
   `ModelAnswered` and `AllowanceSpent` carry `Allowance? allowance`, read
   from the headers in `WorkerModelGateway._post`'s callers; absent headers
   leave it null, so an older Worker is not a failure. The `recaps` counter is
   ignored on the phone for now; only the `extract` endpoint's headers are
   read into `Allowance`.
3. **The phone remembers it.** `DevicePreferences.scanAllowance(uid)` and
   `rememberScanAllowance(uid, Allowance)`, per account like
   `hasExplainedMissingPhotos`, because the allowance is the account's and a
   second account on the same phone has its own. `InboxBloc` writes it
   whenever an answer carries one. `InMemoryDevicePreferences` grows the
   same two methods and a constructor argument to seed one.
4. **Settings draws it.** The row above, reading the preference once in
   `initState` beside the Lock's read, and deciding the state from
   `Allowance.resetsAt` against the clock handed down (`Clock`, never
   `DateTime.now()`).

## Text scaling and language

- The label "Daily cap" wraps to two lines at large text sizes as the column
  allows; the figure line wraps the word under the figure if it must, and the
  track keeps the column's width.
  `nothing_clips_at_twice_the_text_size_test.dart` covers Settings; the new
  row is inside it.
- Chinese: `settingsDailyCap` "每日上限", `settingsDailyCapScansToday`
  "今天的扫描", `settingsDailyCapScansADay` "每天的扫描",
  `settingsDailyCapGoverns` "模型一天为你读取多少张收据。用完之后，新的照片会在收件箱里等到明天。"
  The mark stays in the case written (`cased` is a no-op in Chinese).
  `both_languages_say_everything_test.dart` will fail until the zh keys land.
- The now-unused `settingsScans*` keys from the old diagnostics panel stay as
  they are; retiring them is not this work.

## Accessibility

- The whole row is one thing to a screen reader: `MergeSemantics` around it,
  as `_Lock` does, so it is read as "Daily cap, 12 of 40 Scans today, How
  many receipts…". The figure's `Text` gets a `semanticsLabel` of
  `settingsDailyCapSpoken(used, cap)` "{used} of {cap}" so "12 / 40" is not
  read as "twelve slash forty"; before the Worker has spoken the figure reads
  as itself.
- The track is decorative and excluded (`ExcludeSemantics`); the figure says
  the same thing.
- Nothing is focusable, so the row is not a stop on the way round the screen.

## Out of scope, said so it is not assumed

- No way to change the cap from the phone. It is a Knob, and the row says
  what it is, not what it could be.
- No count of Recaps.
- No refresh on a timer. The row shows what was last heard; the next Scan
  updates it.
