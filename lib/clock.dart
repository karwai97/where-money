/// What time it is, asked rather than read, so that a test above the blocs can
/// answer it.
///
/// A function and not a `DateTime` because the widget holding one is built at
/// launch and the blocs below it are built later, on sign-in — a value handed
/// down at launch would already be stale by the time anything read it. It is
/// still asked only once per bloc, so a Ledger left open across midnight on
/// the 1st goes on naming last month until the screen is rebuilt. That is the
/// behaviour `LedgerBloc` has always had; this seam does not change it.
typedef Clock = DateTime Function();
