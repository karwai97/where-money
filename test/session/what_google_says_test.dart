import 'package:flutter_test/flutter_test.dart';
import 'package:where_money/session/sign_in_gateway.dart';

/// Firebase keeps a copy of the name and the picture, taken from the
/// credential the first time an account signed in. That copy can be missing
/// both while Google has both — an account on the test phone is exactly that
/// — so Google's own answer wins and Firebase's is what is left when Google
/// has nothing to say.
void main() {
  const firebase = SignedInUser(
    uid: 'kai-uid',
    name: 'Kai',
    email: 'kai@example.com',
  );

  final google = GoogleProfile(
    email: 'kai@example.com',
    name: 'Kar Wai Ngim',
    picture: Uri.parse('https://lh3.googleusercontent.com/a/kai'),
  );

  test('Google names the user where Firebase has an older name', () {
    final described = firebase.describedBy(google);

    expect(described.name, 'Kar Wai Ngim');
    expect(
      described.picture,
      Uri.parse('https://lh3.googleusercontent.com/a/kai'),
    );
  });

  test('Google fills in what Firebase never had', () {
    const nameless = SignedInUser(uid: 'kai-uid', email: 'kai@example.com');

    final described = nameless.describedBy(google);

    expect(described.name, 'Kar Wai Ngim');
    expect(described.picture, isNotNull);
  });

  test('Firebase is what is left when Google says nothing', () {
    expect(firebase.describedBy(null), firebase);
    expect(
      firebase.describedBy(const GoogleProfile(email: 'kai@example.com')).name,
      'Kai',
    );
  });

  test('the uid is never Google to change', () {
    expect(firebase.describedBy(google).uid, 'kai-uid');
  });

  test('another account on the same phone describes nobody here', () {
    // The phone this was built on has two Google accounts on it. A session
    // restored for one of them while Firebase holds the other would
    // otherwise put one person's name and face over another person's Ledger.
    final somebodyElse = GoogleProfile(
      email: 'someone@example.com',
      name: 'Someone Else',
      picture: Uri.parse('https://lh3.googleusercontent.com/a/else'),
    );

    expect(firebase.describedBy(somebodyElse), firebase);
  });

  test('a guest is described by nobody, having no address to match on', () {
    const guest = SignedInUser(uid: 'guest-uid', guest: true);

    expect(guest.describedBy(google), guest);
  });
}
