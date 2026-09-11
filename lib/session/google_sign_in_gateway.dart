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

  /// What Google says about this account, taken off the Firebase record's own
  /// provider data. A guest has no provider at all and so no profile.
  ///
  /// Asking the SDK is the obvious way and the wrong one. Its
  /// `attemptLightweightAuthentication` is allowed to show UI, and on Android
  /// it does: it put an account chooser in front of a user who was already
  /// signed in. This costs no call at all — Firebase already holds what the
  /// Google provider said, and holds it *per provider*, which is the copy
  /// that survives when the user record's own is empty.
  ///
  /// The picture is parsed here, at the seam, so a URL nothing can parse is
  /// simply no picture rather than a failure inside an image loader.
  static GoogleProfile? _googleIn(User user) {
    for (final provider in user.providerData) {
      final email = provider.email;
      if (provider.providerId != _googleProvider || email == null) continue;

      return GoogleProfile(
        email: email,
        name: provider.displayName,
        picture: switch (provider.photoURL) {
          final url? => Uri.tryParse(url),
          null => null,
        },
      );
    }
    return null;
  }

  /// Firebase's own id for the Google provider, which is the string it keys
  /// `providerData` by rather than anything this app chose.
  static const _googleProvider = 'google.com';

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
  static SignedInUser _asUser(User user) => SignedInUser(
    uid: user.uid,
    name: user.displayName,
    email: user.email,
    picture: switch (user.photoURL) {
      final url? => Uri.tryParse(url),
      null => null,
    },
    guest: user.isAnonymous,
  ).describedBy(_googleIn(user));

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
    await _auth.signOut();
  }
}
