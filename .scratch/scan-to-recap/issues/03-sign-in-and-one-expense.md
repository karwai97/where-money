# 03 — Sign in, and one Expense round-trips

**What to build:** A user signs in with Google and sees a Ledger. The Ledger has
exactly one Expense in it, put there by a debug button rather than by a receipt —
but it was written to Firestore, read back, and rendered, which proves the spine
the rest of the app hangs on.

This is the ticket that establishes the seam. The repository is the only place
Firestore's shape is known; nothing above it ever sees an untyped document.
Security rules restrict every path to its owning user, and a signed-out or
wrong-user read is refused by the rules rather than by app code.

**Blocked by:** 01

**Status:** ready-for-agent

- [ ] Signing in with Google succeeds on a physical device, with SHA-1 registered
- [ ] The session survives killing and relaunching the app
- [ ] A debug action writes an Expense, and it appears in the Ledger list
- [ ] The Expense survives a relaunch, and survives a reinstall
- [ ] No type above the repository mentions a Firestore document, snapshot or map
- [ ] Security rules deny reads and writes to another user's path, verified by test rather than by inspection
- [ ] Signing out clears the Ledger from view
