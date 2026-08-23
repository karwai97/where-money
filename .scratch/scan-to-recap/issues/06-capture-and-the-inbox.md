# 06 — Capture and the Inbox

**What to build:** A user photographs a receipt and the app is immediately done
with them. The photo is saved, a Scan appears in the Inbox, and they can
photograph the next one without waiting. Nothing is extracted yet — the Inbox just
shows Scans sitting at `captured`.

The point of this ticket is that capture cannot fail. It touches no network, so it
works in airplane mode and in a basement, and it is durable the moment the shutter
fires. Clearing a wallet of receipts should be one sitting, not ten round trips.

The image is resized on device to roughly 1024px on the long edge before it is
stored. The prototype measured that a portrait receipt saturates the model's patch
budget at about 1440px, so asking for the phone's full resolution bills identically
while costing real upload bandwidth.

**Blocked by:** 03

**Status:** ready-for-agent

- [ ] A photo can be taken with the camera or chosen from the gallery
- [ ] The Scan and its image exist on disk before the capture screen is dismissed
- [ ] Capture works with the network off, with no error and no difference in behaviour
- [ ] Several receipts can be captured back to back with no waiting between them
- [ ] The stored image is resized to roughly 1024px on the long edge
- [ ] The Inbox lists every un-Reviewed Scan with its state
- [ ] Scans survive force-quitting the app
- [ ] The Inbox count is visible from the main screen
- [ ] A Scan can be abandoned, which removes its image from disk
- [ ] Nothing but the user deletes a Scan
