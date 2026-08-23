# 12 — The biometric lock

**What to build:** Someone holding the user's unlocked phone cannot read their
spending. The app asks for a fingerprint or the device PIN when it opens, and the
user can turn that off if they would rather have the convenience.

This is deliberately separate from signing in, because the two do different jobs
and conflating them is the mistake. Signing in identifies the user to the Worker so
their Scan allowance can be counted — it protects the OpenAI bill. The lock
protects the data on this device. Neither substitutes for the other.

Also here: the new-device story. Signing in on a new phone brings back every
Expense from Firestore and no receipt images, because images are device-local by
design. That is a fine trade but a confusing surprise, so the app says it once
rather than leaving the user to notice missing photos.

**Blocked by:** 03

**Status:** ready-for-agent

- [ ] The app requires biometric or device-PIN authentication on open when enabled
- [ ] A device with no biometrics enrolled falls back to the device PIN
- [ ] A device with no secure lock at all is handled without locking the user out of their own data
- [ ] The lock can be turned off in settings, and the choice persists
- [ ] Backgrounding and returning re-locks after a short interval, not on every task switch
- [ ] Signing out is available and clears the session
- [ ] Signing in on a device with no local images explains once that Expenses came back and photos did not
