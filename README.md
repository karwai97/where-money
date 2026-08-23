# where_money

Photograph a receipt, put the phone away. The photo becomes a categorised ledger
entry, and a month of entries becomes a short written account of where the money
went.

The spec and its tickets are in [.scratch/scan-to-recap/](.scratch/scan-to-recap/),
the domain language in [CONTEXT.md](CONTEXT.md), and the decisions worth arguing
with in [docs/adr/](docs/adr/).

## Layout

A pub workspace of two Dart packages:

- **the repo root** — the Flutter app. UI, Bloc, Firebase, camera, charts.
- **[packages/core](packages/core)** — `where_money_core`. The domain types, the
  Check, the Rollup, the Model wire shapes, the cost maths. Pure Dart: its
  pubspec declares no Flutter dependency, and `depend_on_referenced_packages` is
  promoted to an error there so the shared workspace resolution cannot smuggle
  `package:flutter` in. Its tests run under `dart test`, with no Flutter harness.

A third deployable, the Cloudflare Worker that holds the OpenAI key, is not a
Dart package and is not here yet (ADR-0001).

## Getting it onto a device

You need Flutter 3.44+, the Android SDK, and the
[Firebase CLI](https://firebase.google.com/docs/cli) logged in to an account
with access to the Firebase project.

```sh
flutter pub get      # resolves the whole workspace

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

## Tests

```sh
dart test                # from packages/core — pure Dart, no Flutter harness
flutter test             # from the root — widgets and blocs
```

## iOS is unbuilt and unverified

The iOS project exists, its bundle id is `com.kai.whereMoney`, and a
Firebase iOS app is registered against it. That is as far as it goes. There is no
Mac in this project's development environment, so nothing under `ios/` has ever
been compiled, run, or tested, and no claim is made that it works. The
deployment target is 15.0, which is `firebase_core`'s floor. Known gaps for
whoever picks it up: `GoogleService-Info.plist` has to be fetched the same way as
the Android config (template alongside it) and then added to the Xcode project,
which takes Xcode; and there is no `Podfile` yet, since Flutter writes one on the
first macOS build.

There is no web build, and there won't be — the camera pipeline is the point.

## Secrets

There are none in this repo, and the app is built without a single `--dart-define`
of one. The OpenAI key exists only as a Cloudflare Worker secret. Model tier,
image size, reasoning effort, and the daily cap are behaviour knobs and will come
from Remote Config; none of them is a secret either.
