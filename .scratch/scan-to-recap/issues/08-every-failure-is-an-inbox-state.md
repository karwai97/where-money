# 08 — Every failure is an Inbox state

**What to build:** Nothing about a failed Scan is a surprise or a dead end. The
Inbox shows what went wrong in words the user can act on, retries what can be
retried, and never loses a photo.

There are no modal error dialogs in this flow. A failure is a state a Scan is in,
which means it is visible whenever the user next looks rather than only at the
moment it happened. Offline is not a special case under this design — the job
simply has not run yet.

The failure taxonomy is the one the prototype established, and each member needs
its own copy because each means something different to the user: the model
refused; reasoning consumed the whole output budget so there is no text at all;
the network is gone; the daily cap is reached; the token was rejected; the photo
is not a receipt.

**Blocked by:** 07

**Status:** ready-for-agent

- [ ] Each failure mode has its own Inbox state and its own plain-language copy
- [ ] A refusal is distinguished from an incomplete response, and both from a network failure
- [ ] Hitting the cap says so and says when it resets — never "something went wrong"
- [ ] A Scan that failed on the network retries by itself once there is signal
- [ ] Any failed Scan can be retried by hand without waiting for the automatic retry
- [ ] No failure mode loses the image or the Scan
- [ ] Retrying a Scan that has already succeeded is not possible
- [ ] A test covers each taxonomy member through the faked gateway
