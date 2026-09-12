# Where Money

Photograph a receipt, put the phone away. The photo becomes a categorised ledger
entry, and a month of entries becomes a short written account of where the money
went.

It is an expense tracker for one person and their own phone. No household
sharing, no bank connection, no budget to set and then fail. The whole of it is
three things: photograph what you spent, correct whatever was misread, and read
the month back at the end of it.

## Photograph, then put the phone away

The photo is the whole of the capture. A Scan exists the moment it is taken —
before anything has been read, before there is a connection — and waits in the
Inbox to be read. Nothing is held up while the model works, so a queue at a till
is four photographs and a pocket.

The Inbox says which state each one is in: waiting to be read, being read, ready
to review, already in the Ledger. When a read fails it says which way it failed
and what to do about it — a clearer photograph, or signing in again, or nothing
at all, because a Scan that lost its connection keeps trying on its own. A photo
that is not a receipt is told apart from a failure, because it is not one.

## Nothing reaches the Ledger unreviewed

Every Scan is reviewed before it becomes an Expense, a clean one included. What
makes that quick rather than dutiful is that the app has already checked the
arithmetic the model was never trusted with: whether subtotal, tax and tip come
to the total, whether the line items sum to what they should, whether the date
is in the future or a year old, whether the currency is a real code. Anything it
noticed sits on the field it is about, in a sentence saying what was read and
why it looks wrong, so a receipt with nothing wrong is one glance and a button.

Categories come from a fixed list of eighteen rather than free text, and the
model has to say why it chose one.

The app also keeps score of itself. Settings shows how many receipts have been
read, how many went through untouched, and which fields Review keeps having to
correct.

## A month at a time

The Ledger opens on the current month and moves a month at a time. Alongside the
list are two charts — where the month went by category, and how the last several
months compare.

An Expense can be corrected or deleted after the fact, and one can be typed in
by hand when there was no receipt to photograph.

## Where your money went

A month with enough in it gets written up: a few sentences on what was spent,
what moved against last month, and what stood out. It is written from the
month's totals rather than from the raw Ledger, so nobody's receipts are handed
over wholesale to have a paragraph written about them.

The charts never need any of this. If the write-up cannot be had — no
connection, or the day's allowance is spent — the month's numbers are still
there, and the app says which it was.

## One currency does the counting

The first Expense sets the Home Currency, and the totals, charts and write-ups
are all in it. An Expense in any other currency is kept exactly as it was paid
and left out of the totals, and the app says so where the totals are rather than
quietly rounding a foreign amount into them. The currency can be changed in
Settings afterwards.

## The receipts stay on the phone

A receipt photo never leaves the phone that took it. The Ledger itself lives in
your account, so signing in on a second phone brings every Expense across — and
brings none of the photos, which the app tells you once rather than showing a
column of broken images.

## An account is optional

The app can be used as a guest. That is a real Ledger with a real allowance, not
a trial, and signing in later keeps it. What it cannot be is recovered: nobody
signs back into a guest Ledger, so signing out deletes it, and the app says that
plainly before it happens.

Separately from any of that, the app can ask for a fingerprint or the phone's PIN
before it will show a Ledger. That guards what is already on the phone; signing
in says who you are to the service that reads receipts. Neither stands in for
the other.

## In twelve languages

English, Chinese, Spanish, Portuguese, French, German, Japanese, Korean,
Russian, Arabic, Hindi and Indonesian — the interface and the monthly write-up
both. A month already written up in one language is served under a new one
rather than bought again, so switching costs nothing.

## How many receipts a day

There is a daily cap on how many receipts get read, counted where it cannot be
argued with rather than on the phone. When it is spent, new photos wait in the
Inbox until tomorrow instead of being refused — capture never depends on the
allowance. Settings shows what today has used and what each Scan is asking for.

## Where it runs

Android. The iOS project exists but has never been built or run, and no claim is
made that it works. There is no web build and there won't be — the camera is
the point.

## The rest of it

- [docs/running-it.md](docs/running-it.md) — the repo's layout, getting it onto
  a device, the tests, and what has to be deployed.
- [CONTEXT.md](CONTEXT.md) — the words this project uses for the things above,
  and the ones it refuses to.
- [docs/adr/](docs/adr/) — the decisions worth arguing with.
- [.scratch/](.scratch/) — a folder per feature, holding its spec and tickets.
  The convention is in [docs/agents/issue-tracker.md](docs/agents/issue-tracker.md).

There are no secrets in this repo. The key that pays for reading receipts lives
only as a Cloudflare Worker secret, and the app is built without a single
`--dart-define` of one.
