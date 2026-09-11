import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'sign_in_gateway.dart';

/// Google's native account picker, exchanged for a Firebase session.
///
/// No client id appears here: `google-services.json` carries the web OAuth
/// client, and the Gradle plugin turns it into the `default_web_client_id`
/// resource the platform side reads. Passing one in Dart would be a second,
/// staler copy of it.
class GoogleSignInGateway implements SignInGateway {
  GoogleSignInGateway({FirebaseAuth? auth, GoogleSignIn? google})
    : _auth = auth ?? FirebaseAuth.instance,
      _google = google ?? GoogleSignIn.instance;

  final FirebaseAuth _auth;
  final GoogleSignIn _google;

  /// What Google last said about the person signed in, or null where it has
  /// said nothing about them — nobody is signed in, the user is a guest, or
  /// the SDK had nothing to restore.
  ///
  /// Held rather than asked for at the point of use. The SDK answers on a
  /// broadcast stream that does not replay and on the return of the two calls
  /// below, so what it says has to be caught where it is said.
  GoogleProfile? _fromGoogle;

  Future<void> initialize() async {
    await _google.initialize();
    _fromGoogle = await _restored();
  }

  /// The Google account behind a session this phone already had, asked for
  /// without any UI, so a returning user is named and pictured on the frame
  /// they come back to rather than a frame later.
  ///
  /// Never allowed to fail a launch or to hold one up for long. Firebase
  /// alone says who is signed in; everything this adds is a name and a face
  /// the screen already has a fallback for, so a phone with no network gets
  /// the fallback rather than a wait.
  Future<GoogleProfile?> _restored() async {
    try {
      final restored =
          await (_google.attemptLightweightAuthentication() ??
                  Future<GoogleSignInAccount?>.value())
              .timeout(const Duration(seconds: 3));
      return _profileOf(restored);
    } catch (_) {
      return null;
    }
  }

  /// The SDK's account as the app's [GoogleProfile]. The picture is parsed
  /// here, at the seam, so a URL nothing can parse is simply no picture
  /// rather than a failure somewhere inside an image loader.
  static GoogleProfile? _profileOf(GoogleSignInAccount? account) =>
      account == null
      ? null
      : GoogleProfile(
          email: account.email,
          name: account.displayName,
          picture: switch (account.photoUrl) {
            final url? => Uri.tryParse(url),
            null => null,
          },
        );

  /// `userChanges` rather than `authStateChanges`: a guest linking an account
  /// keeps their uid, so the auth *state* does not change and that stream
  /// never fires — the app would go on believing a linked user is a guest.
  ///
  /// The extra emissions this brings, a token refresh among them, cost
  /// nothing: [SignedInUser] is an `Equatable` of five fields, so an unchanged
  /// user emits an equal value and no state changes.
  @override
  Stream<SignedInUser?> changes() =>
      _auth.userChanges().map((user) => user == null ? null : _asUser(user));

  /// Firebase's user as the app's, wearing whatever Google says about them.
  /// Firebase settles who this is — the uid the Ledger is keyed by, and
  /// whether it is a guest — and Google settles what they are called and what
  /// they look like. [SignedInUser.describedBy] says how the two are put
  /// together, and why that is not simply Google winning.
  SignedInUser _asUser(User user) => SignedInUser(
    uid: user.uid,
    name: user.displayName,
    email: user.email,
    picture: switch (user.photoURL) {
      final url? => Uri.tryParse(url),
      null => null,
    },
    guest: user.isAnonymous,
  ).describedBy(_fromGoogle);

  @override
  Future<void> signIn() async {
    await _auth.signInWithCredential(await _credential());
  }

  @override
  Future<void> continueAsGuest() async {
    await _auth.signInAnonymously();
  }

  @override
  Future<void> linkWithGoogle() async {
    final credential = await _credential();
    // Only ever called from a row drawn for a signed-in guest. Being asked
    // to keep a Ledger nobody owns is a bug in the caller, and signing
    // somebody in instead would hide it.
    final user = _auth.currentUser;
    if (user == null) {
      throw StateError('There is no Ledger to keep: nobody is signed in.');
    }

    try {
      await user.linkWithCredential(credential);
    } on FirebaseAuthException catch (error) {
      if (error.code == 'credential-already-in-use' ||
          error.code == 'email-already-in-use') {
        // Firebase hands back a refreshed credential with the error where it
        // has one, and a single-use credential is not worth betting against.
        throw AccountAlreadyHasALedger(error.credential ?? credential);
      }
      rethrow;
    }
  }

  @override
  Future<void> signInWith(Object credential) async {
    await _auth.signInWithCredential(credential as AuthCredential);
  }

  /// The account picker, and the token it hands back. Shared by signing in and
  /// by linking, which differ only in what they do with the answer.
  Future<AuthCredential> _credential() async {
    final GoogleSignInAccount account;
    try {
      account = await _google.authenticate();
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        throw const SignInAbandoned();
      }
      rethrow;
    }

    // Caught here because this is where Google says it. Set before the
    // Firebase call this feeds returns, so the emission that follows it is
    // already the described user rather than a bare one that is corrected a
    // frame later.
    _fromGoogle = _profileOf(account);

    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw StateError('Google signed $account in without an ID token.');
    }

    return GoogleAuthProvider.credential(idToken: idToken);
  }

  @override
  Future<void> deleteAccount() async {
    await _auth.currentUser?.delete();
  }

  @override
  Future<void> signOut() async {
    // Google first: signing Firebase out first would briefly show a signed-out
    // Ledger while the picker still remembers the account.
    await _google.signOut();
    _fromGoogle = null;
    await _auth.signOut();
  }
}
