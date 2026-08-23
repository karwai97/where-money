# 01 — Workspace, packages, and an app that launches

**What to build:** A developer clones the repo, runs one command, and gets the app
on an Android device. Nothing is on screen yet beyond a placeholder, but the
skeleton every other ticket builds into exists and the boundary that matters is
enforced.

Two packages in a pub workspace: the core package, which is pure Dart and must
never depend on Flutter, and the app package, which does. The boundary is
enforced by the core package's pubspec having no Flutter dependency, so a stray
Flutter import in core is a compile error rather than a code-review comment.
Firebase is wired far enough that later tickets can add Auth, Firestore and
Remote Config without touching project setup again.

**Blocked by:** None — can start immediately.

**Status:** ready-for-agent

- [x] `flutter run` installs and launches on a physical Android device
- [x] The core package's tests run with `dart test`, with no Flutter test harness
- [x] Adding a Flutter import to the core package fails to compile
- [x] Firebase is configured for Android, with `google-services.json` gitignored and a committed template alongside it
- [x] The iOS project exists and is configured, and the README says plainly that it is unbuilt and unverified
- [x] No secret of any kind is present in the app package or in a build-time define

## Comments

Implemented. The workspace root is the Flutter app itself, so `flutter run` at
the clone root is the one command; `packages/core` is the pure-Dart member.

Verified on a physical device (OPPO CPH2499, Android 16): debug APK built with
the google-services plugin, installed, launched, `FirebaseApp initialization
successful` in logcat, placeholder on screen.

Two notes on the Flutter-free boundary. A pub workspace shares one package
resolution, so `package:flutter` is reachable from `packages/core` unless told
otherwise — importing it there crashes the CFE rather than reporting a clean
error. `depend_on_referenced_packages` is therefore promoted to an error in
`packages/core/analysis_options.yaml`, and a test asserts the pubspec declares
nothing Flutter-shaped, so the boundary fails loudly in the editor and in CI.

iOS: the project exists, bundle id `com.kai.whereMoney`, deployment target
15.0 (`firebase_core`'s floor), Firebase iOS app registered, plist gitignored
with a template. It has never been compiled. Adding `GoogleService-Info.plist`
to the Xcode project needs a Mac, as does generating the Podfile, and both are
left for whoever has one; the README says so.

Verified against a fresh clone of the pushed repo, not just the working tree:
`flutter pub get`, `dart test` in `packages/core`, `flutter analyze`, and
`flutter test` all pass, and `flutter run` installed and launched on the device.

One honest gap against the "one command" framing: because `google-services.json`
is gitignored, a fresh clone's first `flutter run` fails at
`processDebugGoogleServices` until the config is fetched. The two criteria pull
against each other and the ticket picked gitignore, so the README leads with the
fetch. The failure names the missing file, so it is legible rather than cryptic.
