---
status: accepted
---

# The Recap is written in the user's Language, and the Language is part of its cache key

A Recap is the one thing on the Rollup screen this app does not write. The chart
above it names Categories in the user's language; the prose beside it has to name
the same things the same way, because a chart saying 外食 above a Recap saying
"dining out" is worse than either alone.

The Model is what writes in the user's language. The prompt does not carry a
single word of it. `rollupPrompt` sends a year, a month, amounts and Category
slugs (ADR-0007), so the two prompts for the same month in two languages are
byte-identical and a test pins that. The Language rides beside the prompt as a
query parameter, which is what ticket 04 taught the Worker to read. So the Model
names the month and the Categories itself, in the language it was told to write
in, and there is no English on the path for it to copy.

**The consequence is that `rollupHash` takes the Language.** A Recap was
documented as a pure function of its Rollup; it is a pure function of its Rollup
and the Language. Hashing only the prompt would key two different answers to the
same slot and serve a user a Recap in a language they had just switched away
from. So the Language is hashed alongside the prompt rather than read out of it —
the one thing in the key that the prompt does not carry, and the doc comment says
why.

Keying the *bloc* by Language was the alternative and was rejected. Re-keying
would throw away a loaded Ledger and fetch it again over the network because
somebody changed a UI preference. Instead the Setting arrives as an event, the
hash misses, one Recap is paid for, and the answer already paid for stays under
its own key — so a user who switches language and switches back reads the first
Recap again and is charged for nothing.

An unrecognised code hashes as itself rather than as the default the Worker will
answer in. That costs at most one Recap nobody asked for; the other way round
serves a Recap in the wrong language, which is the failure worth avoiding.

**Why a month has no Recap is a kind, not a sentence.** The six reasons used to
be English strings inside the bloc, which is below the app's words. They are
`WhyNoRecap` members now, turned into copy by one exhaustive switch on the screen
that shows them — the same shape as `finding_copy.dart` and for the same reason.
That has a consequence worth naming: the *reason* is read in the language the
interface is in, while the *Recap* is in the language it was asked for. Those can
disagree for as long as a cached English Recap is on a Chinese screen. That is
the intended trade — the alternative is buying a translation of a month the user
has already paid to have written.

**An Extraction keeps whatever language it was read in.** The reasons the Model
gives for flagging a Scan take the same route through the extraction endpoint,
but only for Scans read after the change. A Scan captured under English and
Reviewed a week later under Chinese still shows its original reasons: re-reading
would spend the user's Scan allowance on cosmetics, and an Extraction is already
a claim made at a moment rather than a live value.
