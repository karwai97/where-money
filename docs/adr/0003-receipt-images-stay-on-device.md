---
status: accepted
---

# Receipt images never leave the device

Every cloud option needs a card: Cloud Storage for Firebase has required Blaze
for all bucket access since October 2025, and R2 wants a payment method even
for its free tier. A Firestore document caps at 1 MiB, so base64 blobs are out.
The resized ~1024px JPEG therefore stays in the app's documents directory with
its path recorded on the Expense.

This turned out to be the better design rather than a consolation. Review needs
the image on screen — "the total looks wrong" is unusable without the receipt
next to it — and having the bytes already on disk is what makes the decoupled
Scan of ADR-0004 possible.

## Consequences

- A reinstall keeps every Expense and loses every image. Accepted deliberately.
