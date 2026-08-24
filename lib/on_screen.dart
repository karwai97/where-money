/// How dates read in the app. One definition, so the Ledger and the Inbox
/// cannot drift into two house styles.
library;

String asDay(DateTime at) => '${at.year}-${_two(at.month)}-${_two(at.day)}';

String asMoment(DateTime at) =>
    '${asDay(at)} ${_two(at.hour)}:${_two(at.minute)}';

String _two(int value) => value.toString().padLeft(2, '0');
