# Where Money

Photograph a receipt, put the phone away. The photo becomes a categorised ledger
entry, and a month of entries becomes a short written account of where the money
went.

A feature's spec and its tickets live in a folder of its own under
[.scratch/](.scratch/), one per feature — the convention is in
[docs/agents/issue-tracker.md](docs/agents/issue-tracker.md). The domain
language is in [CONTEXT.md](CONTEXT.md), and the decisions worth arguing with
in [docs/adr/](docs/adr/).

## Layout

A pub workspace of two Dart packages:

- **the repo root** — the Flutter app. UI, Bloc, Firebase, camera, charts.
- **[packages/core](packages/core)** — `where_money_core`. The domain types, the
  Check, the Rollup, the Model wire shapes, the cost maths. Pure Dart: its
  pubspec declares no Flutter dependency, and `depend_on_referenced_packages` is
  promoted to an error there so the shared workspace resolution cannot smuggle
  `package:flutter` in. Its tests run under `dart test`, with no Flutter harness.

- **[lib/l10n](lib/l10n)** — the app's words, one hand-written ARB file per
  language, and the key convention the rest of them follow. Twelve of them:
  English, Chinese, Spanish, Portuguese, French, German, Japanese, Korean,
  Russian, Arabic, Hindi, Indonesian. The codes are a closed list in
  `packages/core`, because the Worker has to agree with the app about what it
  is being asked to write in. `AppLocalizations` is generated from the ARB
  files by `flutter pub get` and by every build, so it is gitignored: an
  analyze or a test run on a fresh clone wants that `pub get` first.
  [lib/l10n/README.md](lib/l10n/README.md) says what adding a thirteenth takes.

- **[tools/launcher-icon](tools/launcher-icon)** — the launcher icon, drawn
  once as a few paths and written out as Android vector drawables, the legacy
  Android PNGs and the iOS icon set. Node, not Dart. Nothing under `android/`
  or `ios/` that it writes is edited by hand; change `make.mjs` and run
  `npm install && npm run make` there.

- **[worker](worker)** — the Cloudflare Worker that holds the OpenAI key
  (ADR-0001). TypeScript, not a Dart package, deployed separately. It is the
  only place the key exists, and it owns the prompt, the schema and the daily
  cap so that a client cannot.

## Getting it onto a device

You need Flutter 3.44+, the Android SDK, and the
[Firebase CLI](https://firebase.google.com/docs/cli) logged in to an account
with access to the Firebase project.

```sh
flutter pub get      # resolves the whole workspace, and writes AppLocalizations

# Firebase config is per-project and gitignored; fetch your own copy.
firebase apps:sdkconfig ANDROID 1:607107275128:android:49602f2c132878e7ca908d \
  --out android/app/google-services.json

flutter run
```

`google-services.json` carries no secret — it is the public client config — but
it is nobody's business but the project owner's, so it stays out of git. The
shape you should get back is in
[android/app/google-services.json.template](android/app/google-services.json.template).
There is no generated `firebase_options.dart`: `Firebase.initializeApp()` reads
the native config file, which keeps project keys out of Dart source entirely.

Google Sign-In will not work until your signing certificate's SHA-1 is
registered on the Android app in the Firebase console. Print the debug one with:

```sh
keytool -list -v -alias androiddebugkey -keystore ~/.android/debug.keystore \
  -storepass android -keypass android
```

Add it under Project settings, then re-fetch `google-services.json` — the file
only grows its `oauth_client` entries once a fingerprint is registered, and
without the web client (`client_type: 3`) sign-in fails with `ApiException: 10`.
Release builds are signed with the debug key today, so only the debug
fingerprint is registered and no claim is made about release sign-in.

## Tests

```sh
dart test                # from packages/core — pure Dart, no Flutter harness
flutter test             # from the root — widgets and blocs

(cd tools/firestore-rules && npm install && npm test)
(cd worker && npm install && npm test)
```

The third one runs [firestore.rules](firestore.rules) against the Firestore
emulator, so what is asserted is what the rules actually do rather than what
they look like they do. It needs Node and a JDK on the path; nothing is sent to
the real project, and the emulator runs under a `demo-` project id so it cannot
be.

The fourth runs the [Worker](worker) against the local Workers runtime, with
Google's signing keys and the model both intercepted. It needs no Cloudflare
account and no OpenAI key; deploying it needs both, and
[worker/README.md](worker/README.md) says how.

## Security rules

The Ledger lives at `users/{uid}/expenses/{id}`, and the rules say only that
path is readable and writable, and only by the user who owns it. Deploy them
before signing in on a device, or every read comes back refused:

```sh
firebase deploy --only firestore:rules
```

## Knobs

Which model reads a receipt, how much reasoning it buys, how large an image it
is given and how many Scans a day are paid for come from Remote Config, with
the same values compiled in behind them so a phone that cannot reach it still
scans. [remoteconfig.template.json](remoteconfig.template.json) is what seeds a
project that has never had a template:

```sh
firebase deploy --only remoteconfig
```

The daily cap it delivers only lowers what the Worker's own ceiling allows.
Raising the ceiling is a Worker deploy, deliberately.

## iOS is unbuilt and unverified

The iOS project exists, its bundle id is `com.kai.whereMoney`, and a
Firebase iOS app is registered against it. That is as far as it goes. There is no
Mac in this project's development environment, so nothing under `ios/` has ever
been compiled, run, or tested, and no claim is made that it works. The
deployment target is 15.0, which is `firebase_core`'s floor. Known gaps for
whoever picks it up: `GoogleService-Info.plist` has to be fetched the same way as
the Android config (template alongside it) and then added to the Xcode project,
which takes Xcode; and there is no `Podfile` yet, since Flutter writes one on the
first macOS build. The app icon set is drawn at every size the asset catalogue
lists, but like everything else here it has never been through Xcode.

There is no web build, and there won't be — the camera pipeline is the point.

## Secrets

There are none in this repo, and the app is built without a single `--dart-define`
of one. The OpenAI key exists only as a Cloudflare Worker secret. Model tier,
image size, reasoning effort and the daily cap come from Remote Config, which is
readable by anyone holding the app; none of them is a secret either, which is
why they are allowed to live there.
