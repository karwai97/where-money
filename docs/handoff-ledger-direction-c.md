# Handoff — the Ledger at direction C, typography settled

Continues `%TEMP%\where_money-direction-c-handoff.md`, which is still accurate
for how direction C was built and what the design canvas holds. Read it for the
canvas working-file chain and the device notes; this document does not repeat
them. Everything it listed as blocked is now unblocked.

## State

| What | Where |
| --- | --- |
| Repo | `C:\Users\User\Android Studio Project\where_money`, branch **`c5-graphite-theme`** |
| Working tree | **clean** — nothing uncommitted |
| Checks | `flutter test` 536 pass; `flutter analyze` one pre-existing `info` |
| Design canvas | https://claude.ai/code/artifact/cafab335-7dce-46f2-9d66-b75fd4bb2ca3 |

Five commits landed on top of `3a2b771`. Read the messages rather than a
summary of them — they carry the reasoning:

```
git log 3a2b771..HEAD
```

- `e5e693f` — direction C, the two-way trend window, the app bar. One commit
  because three strands of work were interleaved in the same lines; its body
  says whose is whose.
- `ef8712f` — `.claude/worktrees/` ignored
- `3f0e9b3` — Public Sans and JetBrains Mono via `google_fonts`
- `a4e05cc` — upper case month labels, the muted text tier, and the weight bug
- `7767f71` — the Ledger's title at 700

## The two traps in this code

Both cost a while to find and neither is visible in a widget test.

**A weight cannot be changed after the fact.** `google_fonts` registers each
weight as a family of its own (`PublicSans_600`, not Public Sans at 600), so a
`copyWith(fontWeight:)` downstream of one sets a number nothing reads. It fails
silently — the text still draws, at 400, or as a synthesised bold. `atItsWeight`
and `asFigures` in `lib/settings/themes.dart` exist only for this. Any new call
site that changes a weight or wants the figure face must go through them.

To check what actually resolved, pump the app in a throwaway test and print
`tester.widget<Text>(finder).style?.fontFamily`. It reads `PublicSans_700`,
`JetBrainsMono_500` and so on. Pixel measurement is too noisy for one weight
step; that method sent this session down a false trail once.

**The trend window is not the month on screen.** `LedgerReady.trend` holds six
months *around* `rollup`, not ending at it, so months after the one on screen
are drawn — that is what makes the trend a way forward. Anything reading
`trend.last` as "the month we are on" is wrong; `MonthColumns` and `MonthTrend`
both take `showing` explicitly for this reason. The rule the window follows is
in `_windowEndingFor` in `lib/ledger/ledger_bloc.dart`.

## Not done

1. **The canvas still says the direction is open.** `Main.dc.html` leads with
   direction A. C is chosen and built. The `design` skill's rule applies: build
   the final into `Main.dc.html`, move the unchosen sketches to another page,
   and stop calling the artifact "…Directions". **This is the largest piece of
   work left.**
2. **No ADR for any of it.** `docs/adr/` has nine entries and a strict
   vocabulary. Three decisions here are arguably ADR-worthy and none is
   recorded: choosing direction C; the accent that could not invert between
   brightnesses; fetching the faces at runtime rather than committing them,
   which is why every figure still asks for tabular numerals.
3. **l10n prefix.** The comparison sentence and the exclusion notice are read on
   two screens now, so by `lib/on_screen.dart`'s own stated convention the six
   `rollup*` keys should drop the prefix. A rename across both ARB files.
4. **Two tokens unmapped.** The small FAB's border uses `outlineVariant`
   (`#262931`) rather than C's `#333744`, which has no Material role.
5. **Inbox, Review and Expense screens** are designed in no theme and unbuilt.

## Constraints that bite

The predecessor document lists these and they all still hold — copy is never
hardcoded, run `flutter gen-l10n` after touching an ARB file, the house dash is
`—` and never ` -- `, comments explain *why* and stay sparse. Two to add:

- **Upper case is typography, not wording.** The month columns, the badge over
  the total and the column heads are cased at the call site with
  `.toUpperCase()`. The ARB files hold them as written, and the transform is a
  no-op in Chinese. Tests that look for a trend column must look for the upper
  case form; `month_on_screen_test.dart` has a `column()` helper for exactly the
  distinction between a column and a sentence naming the same month.
- **A supporting line is muted by being supporting.** `bodySmall` and
  `labelSmall` carry `onSurfaceVariant` from the theme. Do not colour a
  secondary line at the call site.

## Verifying on the phone

Every visual finding across both sessions came from the device, not the suite —
the FAB reading `primaryContainer`, the empty-month dead end, the ink tier and
the inert weights. The device notes in the predecessor document still apply
(CPH2499, `ce369333`, `adb shell svc power stayon true`, capture with
`adb exec-out screencap -p` and strip the warning before the PNG signature).

One thing that document does not say: **do not pipe `flutter run` through
`tail`** — it buffers and you get nothing. Redirect to a file and poll it.

## Suggested skills

Call the `Skill` tool for:

- **`design`** — required before touching the canvas at all, which is item 1
  above. It has a specific procedure for editing an existing canvas and specific
  publish rules (every publish passes `contract: "0.1.31"`; a republish **omits**
  `capabilities`, since passing a fresh set could strip saving for everyone).
- **`mattpocock-skills:domain-modeling`** — for item 2. `docs/adr/` has a strict
  vocabulary and `CONTEXT.md` is the project's own; do not write an ADR freehand.
- **`run`** — before claiming any Ledger change works.
- **`lean-comments`** — both `CLAUDE.md` files ask for sparse comments and this
  session added several long ones. `month_header.dart`, `left_out.dart`,
  `themes.dart` and the rewritten parts of `ledger_screen.dart` are worth a pass.
- **`unslop`** — for anything that ships as prose.
- **`mattpocock-skills:tdd`** — if you take on item 5, the unbuilt screens.

## Housekeeping

This file is at `docs/handoff-ledger-direction-c.md` because that is where it
was asked for. Note that `.gitignore` carries a repo-wide `*-handoff.md` rule,
in a block whose comment calls agent scratch "per-machine, per-session"; this
name does not match that pattern, so the file **will** be tracked if added.
Whether a handoff belongs in the tracked documentation tree is a call for
whoever owns the repo — it is left uncommitted.
