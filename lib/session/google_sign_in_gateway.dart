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

  Future<void> initialize() => _google.initialize();

  @override
  Stream<SignedInUser?> changes() => _auth.authStateChanges().map(
    (user) => user == null
        ? null
        : SignedInUser(
            uid: user.uid,
            name: user.displayName,
            email: user.email,
          ),
  );

  @override
  Future<void> signIn() async {
    final GoogleSignInAccount account;
    try {
      account = await _google.authenticate();
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        throw const SignInAbandoned();
      }
      rethrow;
    }

    final idToken = account.authentication.idToken;
    if (idToken == null) {
      throw StateError('Google signed $account in without an ID token.');
    }

    await _auth.signInWithCredential(
      GoogleAuthProvider.credential(idToken: idToken),
    );
  }

  @override
  Future<void> continueAsGuest() async {
    // Not `signInAnonymously()`, though that is the shape this will almost
    // certainly take: an anonymous account keeps every seam keyed by uid
    // working and can be linked to Google later without the Ledger moving.
    //
    // What is not settled is what a guest is told they keep and give up, and
    // whether Settings grows a row that trades the guest session for an
    // account. Until that ADR lands, this refuses rather than creating real
    // accounts nobody has decided the meaning of — the screen surfaces the
    // refusal the way it surfaces Google's.
    throw UnimplementedError(
      'Continuing as a guest is not built yet: what a guest keeps is still '
      'being decided.',
    );
  }

  @override
  Future<void> signOut() async {
    // Google first: signing Firebase out first would briefly show a signed-out
    // Ledger while the picker still remembers the account.
    await _google.signOut();
    await _auth.signOut();
  }
}
