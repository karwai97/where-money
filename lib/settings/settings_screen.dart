import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:where_money_core/where_money_core.dart';

import '../a_form_of_rows.dart';
import '../choosing_a_currency.dart';
import '../clock.dart';
import '../data/device_preferences.dart';
import '../l10n/app_localizations.dart';
import '../ledger/ledger_bloc.dart';
import '../on_screen.dart';
import '../lock/device_lock.dart';
import '../session/session_bloc.dart';
import '../session/trading_a_guest_for_an_account.dart';
import 'initials.dart';
import 'settings_cubit.dart';
import 'themes.dart';

/// The Settings, in Review's hand: the Setting's name in the tracked label
/// column, its value in a filled cell beside it, the sentence about it
/// indented under the cell, and a hairline between rows.
///
/// One table, with no heads over it. Review has heads because it has two
/// dozen fields and a reader needs telling where the receipt stops and the
/// money starts; four rows do not, and a strip over three of them said the
/// split ADR-0009 draws out loud without anybody asking it to. What each
/// Setting is for is under the row it is about, which is where this app says
/// things.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.dailyCap,
    required this.clock,
  });

  /// The Scans a day the app asks for, and what time it is. Handed down as
  /// plain values like the Knobs they came from, because this screen is a
  /// pushed route: a route is a sibling of the screen that pushed it, so the
  /// one thing that can reach it is the constructor.
  final int dailyCap;
  final Clock clock;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  LockAvailability? _availability;
  bool? _locks;
  Allowance? _allowance;

  @override
  void initState() {
    super.initState();
    _read();
  }

  Future<void> _read() async {
    final preferences = context.read<DevicePreferences>();
    final session = context.read<SessionBloc>().state;
    final availability = await context.read<DeviceLock>().availability();
    final locks = await preferences.locksOnOpen();
    // The allowance is the account's, so a second account on this phone has
    // its own. This screen is only reachable from a signed-in Ledger, so the
    // other lane is arithmetic rather than a state anybody sees.
    final allowance = session is SignedIn
        ? await preferences.scanAllowance(session.user.uid)
        : null;
    if (mounted) {
      setState(() {
        _availability = availability;
        _locks = locks;
        _allowance = allowance;
      });
    }
  }

  Future<void> _want(bool locks) async {
    setState(() => _locks = locks);
    await context.read<DevicePreferences>().setLocksOnOpen(locks);
  }

  /// An account holder leaves in one tap: their Ledger waits for them, and
  /// nothing about that is worth confirming. A guest's Ledger does not wait,
  /// so a guest is asked, and this screen stays put while the erasure runs —
  /// it can fail, and a popped screen has nowhere to say so.
  Future<void> _signOut() async {
    final session = context.read<SessionBloc>();
    final guest = _guestNow;

    if (guest == null) {
      Navigator.of(context).pop();
      session.add(const SignOutRequested());
      return;
    }

    final words = AppLocalizations.of(context);
    final agreed = await _asked(
      title: words.settingsSignOutAsGuestTitle,
      body: words.settingsSignOutAsGuestBody,
      going: words.settingsSignOutConfirm,
      staying: words.settingsSignOutKeep,
    );
    if (!agreed || !mounted) return;

    await _whileTheScreenIsHeld(
      () => context.read<TradingAGuestForAnAccount>().leave(guest),
    );
  }

  /// The guest's uid, or null when the user has an account. Read off the
  /// session rather than held, so the row and the dialog cannot disagree with
  /// each other about who is signed in.
  ///
  /// [_guestNow] for the handlers and [_guestDrawn] for the drawing: a
  /// handler must not subscribe, and the row has to be redrawn the moment a
  /// guest stops being one — which is what keeping the Ledger does.
  String? get _guestNow => _guestIn(context.read<SessionBloc>().state);

  String? get _guestDrawn => _guestIn(context.watch<SessionBloc>().state);

  String? _guestIn(SessionState session) =>
      session is SignedIn && session.user.guest ? session.user.uid : null;

  /// Keeping the Ledger. Drawn in the row rather than over the screen: it is
  /// a small thing, and a modal over it would be heavy. The collision it may
  /// run into is destructive from its confirmation onward, and takes the
  /// modal from there.
  Future<void> _keep() async {
    final guest = _guestNow;
    if (guest == null) return;

    final trading = context.read<TradingAGuestForAnAccount>();
    var destructive = false;

    await trading.keep(guest, () async {
      final words = AppLocalizations.of(context);
      final agreed = await _asked(
        body: words.settingsAccountInUseBody,
        going: words.settingsAccountInUseConfirm,
        staying: words.settingsSignOutKeep,
      );
      destructive = agreed;
      if (agreed && mounted) _holdTheScreen();
      return agreed;
    });

    if (destructive && mounted) {
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  /// The question, in the shape the Inbox and an Expense already ask one.
  Future<bool> _asked({
    String? title,
    required String body,
    required String going,
    required String staying,
  }) async {
    final agreed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: title == null ? null : Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(staying),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(going),
          ),
        ],
      ),
    );
    return agreed ?? false;
  }

  /// A deletion, held under a modal for as long as it takes. The register
  /// changes at the point something is about to be destroyed, which is the
  /// one place in this flow the user should feel it.
  Future<void> _whileTheScreenIsHeld(Future<void> Function() doing) async {
    _holdTheScreen();
    try {
      await doing();
    } finally {
      if (mounted) Navigator.of(context, rootNavigator: true).pop();
    }
  }

  void _holdTheScreen() => showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (context) => PopScope(
      canPop: false,
      child: Center(
        child: CircularProgressIndicator(
          semanticsLabel: AppLocalizations.of(context).settingsErasingInFlight,
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    final words = AppLocalizations.of(context);

    return Scaffold(
      appBar: barNamed(context, words.settingsTitle),
      body: ListView(
        children: [
          const _ThemeChoice(),
          const _LanguageChoice(),
          _Lock(availability: _availability, locks: _locks, onWanted: _want),
          const _HomeCurrencyChoice(),
          _DailyCap(
            allowance: _allowance,
            requestedCap: widget.dailyCap,
            now: widget.clock(),
          ),
          // The one gap on the screen. Everything above it is a table and is
          // ruled rather than spaced; this is not part of the table.
          const SizedBox(height: 24),
          const _WhoIsSignedIn(),
          if (_guestDrawn != null) _KeepThisLedger(onPressed: _keep),
          _SignOut(onPressed: _signOut),
        ],
      ),
    );
  }
}

class _ThemeChoice extends StatelessWidget {
  const _ThemeChoice();

  @override
  Widget build(BuildContext context) {
    final words = AppLocalizations.of(context);

    return Ruled(
      child: Closed<ThemeMode>(
        name: 'theme',
        label: words.settingsTheme,
        value: context.watch<SettingsCubit>().state.theme,
        // Material's own order, which is also the order of the choice: follow
        // the phone, or override it one way or the other.
        options: ThemeMode.values,
        // Exhaustive, so this is never reached — but the Theme still has a
        // default, and it is the same one the Settings start on.
        whenUnrecognised: ThemeMode.system,
        copy: (theme) => switch (theme) {
          ThemeMode.system => words.settingsThemeSystem,
          ThemeMode.light => words.settingsThemeLight,
          ThemeMode.dark => words.settingsThemeDark,
        },
        onChosen: context.read<SettingsCubit>().chooseTheme,
      ),
    );
  }
}

/// Beside the Theme one, and the same shape: two choices of the same kind
/// should look like the same kind of thing.
class _LanguageChoice extends StatelessWidget {
  const _LanguageChoice();

  @override
  Widget build(BuildContext context) {
    final words = AppLocalizations.of(context);

    return Ruled(
      child: Closed<String>(
        name: 'language',
        label: words.settingsLanguage,
        value: context.watch<SettingsCubit>().state.language,
        // The order is the domain's closed set, so a third language is a list
        // entry there and nothing here.
        options: languages,
        // A language this build does not have is read in the one it falls back
        // to, which is the language it is already being read in.
        whenUnrecognised: defaultLanguage,
        // Named in `on_screen.dart` with the domain's other vocabulary, so the
        // name of a language is decided once, like the name of a Category.
        copy: (language) => languageLabel(words, language),
        onChosen: context.read<SettingsCubit>().chooseLanguage,
      ),
    );
  }
}

/// The one Setting that is a switch rather than a value. Composed here rather
/// than out of [Closed] or [Chosen]: a switch is its own shape and gets no
/// cell behind it, and its name has to be read out with its state.
class _Lock extends StatelessWidget {
  const _Lock({
    required this.availability,
    required this.locks,
    required this.onWanted,
  });

  /// Both null until the phone has said what it can ask. The row is drawn as
  /// its name and nothing else in the meantime — a switch arriving is better
  /// than a row arriving, and nothing else on this screen waits on this read.
  final LockAvailability? availability;
  final bool? locks;

  final ValueChanged<bool> onWanted;

  @override
  Widget build(BuildContext context) {
    final words = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final name = inTheLabelColumn(context, words.settingsLock);

    return Ruled(
      // One thing to a screen reader, so the switch is announced with its name
      // and its state and the sentence is read with it. That sentence is the
      // whole of the row in two of its three states.
      //
      // The [Semantics] inside is what supplies the name, and on its own it
      // would merge the subtree too — a `Semantics` without `container: true`
      // does. This says the intent rather than leaning on that; the claim
      // itself is pinned by `settings_in_graphite_test.dart`.
      child: MergeSemantics(
        child: Semantics(
          label: words.settingsLock,
          child: switch ((availability, locks)) {
            (final LockAvailability can, final bool locking) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    name,
                    const SizedBox(width: labelGap),
                    Expanded(
                      child: Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: Switch(
                          // A phone with nothing to ask cannot make the
                          // promise, and a switch that says it does would be a
                          // lie. Drawn all the same: the sentence under it is
                          // how the user finds out what to do about that.
                          value: locking && can != LockAvailability.none,
                          onChanged: can == LockAvailability.none
                              ? null
                              : onWanted,
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: EdgeInsetsDirectional.only(start: sayingIndent(context), top: 2),
                  child: Text(switch (can) {
                    LockAvailability.biometrics => words.settingsLockBiometrics,
                    LockAvailability.deviceCredential =>
                      words.settingsLockDeviceCredential,
                    LockAvailability.none => words.settingsLockUnavailable,
                  }, style: theme.textTheme.bodySmall),
                ),
              ],
            ),
            _ => Row(children: [name]),
          },
        ),
      ),
    );
  }
}

/// The one Setting that is about the money rather than about this phone
/// (ADR-0009). It changes freely and says so in place: no dialog asking
/// whether the user meant it, because the house style says things where they
/// happen, and the line under the row already says what it governs.
class _HomeCurrencyChoice extends StatelessWidget {
  const _HomeCurrencyChoice();

  @override
  Widget build(BuildContext context) {
    final words = AppLocalizations.of(context);
    final small = Theme.of(context).textTheme.bodySmall;
    final currency = context.watch<SettingsCubit>().state.homeCurrency;
    // Where it came from, worked out rather than remembered: it was taken from
    // the first Expense exactly when it still matches what that Expense would
    // teach. Somebody who has since chosen a different one is not told a
    // provenance that stopped being true when they changed it.
    final learned = learnableCurrency(
      context.watch<LedgerBloc>().state.expenses,
    );

    return Ruled(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Chosen(
            label: words.settingsHomeCurrency,
            // Empty rather than a dash or a placeholder: a code the app does
            // not have is not a thing to draw, and the sentence under the cell
            // says what will set it.
            value: currency ?? '',
            onTap: () async {
              final cubit = context.read<SettingsCubit>();
              final chosen = await chooseACurrency(context, current: currency);
              if (chosen != null) await cubit.chooseHomeCurrency(chosen);
            },
          ),
          Padding(
            padding: EdgeInsetsDirectional.only(start: sayingIndent(context), top: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (currency == null)
                  Text(words.settingsHomeCurrencyNone, style: small)
                else if (currency == learned)
                  Text(words.settingsHomeCurrencyInferred, style: small),
                Text(words.settingsHomeCurrencyGoverns, style: small),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The day's Scans against the cap. Not a Setting: there is no way to change
/// the cap from the phone, and nothing here answers a tap. It sits with the
/// Settings because the sentence under it is the kind of thing this screen
/// says, and it is drawn read-only — no cell, no fill, nothing to land on.
///
/// Every figure came from the Worker. The cap the app *asks* for is a Knob and
/// the cap the Worker *enforces* is that clamped under the deployment's
/// ceiling, which is why the row shows the requested one only until the Worker
/// has answered once on this phone — and why the number can drop when it does.
class _DailyCap extends StatelessWidget {
  const _DailyCap({
    required this.allowance,
    required this.requestedCap,
    required this.now,
  });

  /// What was last heard, or null while the read is still out and on a phone
  /// the Worker has never answered on. Both draw the same thing, the way the
  /// Lock's row draws its name while its own read is out: a figure arriving in
  /// place beats a spinner.
  final Allowance? allowance;

  /// The cap the app asks for, drawn until the Worker has said what it
  /// actually enforces. A Knob, handed down as a plain value.
  final int requestedCap;

  /// What time it is, asked of the clock this app was handed rather than of
  /// the machine, so a test that pins a day is not left reading the calendar.
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final words = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colours = theme.colorScheme;

    // The day rolls over in UTC, which is midnight nowhere this app is read,
    // so `resetsAt` is the only clock that counts and nothing here works one
    // out for itself. That rule is [Allowance]'s; this only draws the answer.
    final heard = allowance;
    final counted = heard != null;
    final cap = heard?.limit ?? requestedCap;
    final used = heard?.usedAt(now) ?? 0;
    // The figure is what the Worker said, unclamped: the counter is
    // approximate and hiding that would be the lie. The track is what does not
    // run past its end.
    final spent = counted && used >= cap;

    return Ruled(
      // One thing to a screen reader: the name, the figure and the sentence
      // are one fact and are read as one.
      child: MergeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                inTheLabelColumn(context, words.settingsDailyCap),
                const SizedBox(width: labelGap),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // The row's own vertical padding, so the figure sits on
                      // the line the cells above it sit on.
                      const SizedBox(height: 8),
                      _Figure(
                        figure: counted ? '$used / $cap' : '$cap',
                        // "12 / 20" read aloud is "twelve slash twenty". The
                        // figure is language-neutral on purpose; how it is
                        // said is not. A cap on its own reads as itself.
                        spoken: counted
                            ? words.settingsDailyCapSpoken(used, cap)
                            : null,
                        word: counted
                            ? words.settingsDailyCapScansToday
                            : words.settingsDailyCapScansADay,
                      ),
                      if (heard != null) ...[
                        const SizedBox(height: 8),
                        // Decorative, and excluded: the figure beside it
                        // already says this.
                        ExcludeSemantics(
                          child: ClipRRect(
                            borderRadius: const BorderRadius.all(
                              Radius.circular(2),
                            ),
                            child: LinearProgressIndicator(
                              value: heard.spentAt(now),
                              minHeight: 3,
                              backgroundColor: colours.surfaceContainerHighest,
                              color: colours.primary,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ],
            ),
            Padding(
              padding: EdgeInsetsDirectional.only(start: sayingIndent(context)),
              // The Inbox's own words for the same news once the day is spent,
              // so the two screens say one thing rather than two.
              child: Text(
                spent
                    ? '${words.inboxCapped} '
                          '${words.inboxMoreScansAt(asMoment(words, heard.resetsAt))}'
                    : words.settingsDailyCapGoverns,
                style: theme.textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The figure and the word beside it: the face `Chosen` sets a currency code
/// in, with the word a size down and on its baseline. The word is [Flexible]
/// so that at twice the text size it wraps rather than running off the column.
class _Figure extends StatelessWidget {
  const _Figure({
    required this.figure,
    required this.spoken,
    required this.word,
  });

  final String figure;

  /// How the figure is read out, or null where it reads as itself.
  final String? spoken;

  final String word;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        // Both flexible, so the column's width is what decides where the line
        // breaks. A figure and the word beside it fit side by side at every
        // size the type ramp reaches; a reader at twice the text size gets a
        // wrapped line rather than a clipped one.
        Flexible(
          child: Text(
            figure,
            semanticsLabel: spoken,
            style: asFigures(
              theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.4,
              ),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Flexible(child: Text(word, style: theme.textTheme.bodySmall)),
      ],
    );
  }
}

/// Whose account this Ledger is under, over the two buttons that are about
/// it. Deliberately not a row in the table: a Setting is a choice about this
/// phone, and who is signed in is neither a choice nor about the phone. The
/// Daily cap already bends that rule once and this does not bend it twice.
///
/// It answers no tap. There is nothing to open — switching accounts is
/// signing out and back in, and both buttons for that are directly under it.
///
/// Read off the session rather than handed down, the way `_guestDrawn` is, so
/// a guest who keeps their Ledger is redrawn as an account holder in the same
/// frame the Keep button disappears.
class _WhoIsSignedIn extends StatelessWidget {
  const _WhoIsSignedIn();

  /// Fixed, and outside the text scaler's reach for the reason [ReceiptMark]
  /// gives: a mark is not type, and initials that grew with the type would
  /// be drawn outside the disc holding them.
  static const _disc = 36.0;

  @override
  Widget build(BuildContext context) {
    final words = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final colours = theme.colorScheme;

    final session = context.watch<SessionBloc>().state;
    // The screen is only reachable signed in, so the other lane is arithmetic
    // rather than a state anybody sees.
    if (session is! SignedIn) return const SizedBox.shrink();
    final user = session.user;

    final name = user.name?.trim();
    final email = user.email;

    // The two lines, settled once, so what the disc holds and what is read
    // out cannot disagree about who this is. [who] names the user and
    // [behind] says what is behind the Ledger, which is the whole of what
    // this block is for.
    final String who;
    final String? behind;
    if (user.guest) {
      // Named rather than left blank: whether there is an account behind the
      // Ledger is a word on the line, not something read off the disc.
      who = words.settingsGuest;
      behind = words.settingsGuestNoAccount;
    } else if (name != null && name.isNotEmpty) {
      who = name;
      behind = email == null
          ? words.settingsSignedInWithGoogle
          : words.settingsSignedInWith(email);
    } else if (email != null) {
      // No display name, which Google can return. The address
      // takes the first line rather than a made-up name, and the line under
      // it is left with the product name alone instead of the address twice.
      who = email;
      behind = words.settingsSignedInWithGoogle;
    } else {
      // Neither, which Google sign-in does not produce — but both fields are
      // nullable, and a lane that draws a blank line over one orphan word is
      // worse than one that says the only thing there is to say, on the line
      // a reader looks at.
      who = words.settingsSignedInWithGoogle;
      behind = null;
    }

    // What the disc holds when there is no picture, and what it falls back to
    // while one loads and if it never arrives: a figure for a guest, the
    // account's initials otherwise.
    final Widget mark = user.guest
        ? Icon(Icons.person_outline, size: 18, color: colours.outline)
        : Padding(
            // Tracking adds space after the last letter only, so tracked
            // initials sit left of centre in a circle. Paid back on the left
            // rather than by dropping the tracking every other mark in the
            // app carries.
            padding: const EdgeInsets.only(left: 1.4),
            child: Text(
              // The trimmed name, not the raw one: whether there is a name to
              // take an initial off is decided once, above, and this must not
              // decide it again.
              initialsOf(name: name, email: email),
              textScaler: TextScaler.noScaling,
              // A tier up from `asAMark`'s `outline`: these sit on a filled
              // cell rather than beside one.
              style: asTrackedMark(
                theme.textTheme.labelSmall?.copyWith(
                  color: colours.onSurfaceVariant,
                ),
              ),
            ),
          );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      // One thing to a screen reader: "Kai, kai@example.com · Google" in one
      // go rather than as two nodes to arrow between.
      child: MergeSemantics(
        child: Row(
          children: [
            // The cell fill every value on the screen sits in, with a person
            // in it. Decoration, and excluded: the lines beside it say
            // everything it says.
            ExcludeSemantics(
              child: Container(
                // Named, so a test that measures it is not bound to which
                // widget happens to be drawing the shape.
                key: const ValueKey('who is signed in: the disc'),
                width: _disc,
                height: _disc,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colours.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                // Clipped rather than shaped: the circle on the decoration
                // is the fill, and a child is not cut by it.
                child: switch (user.picture) {
                  null => mark,
                  final picture => ClipOval(
                    child: Image.network(
                      picture.toString(),
                      width: _disc,
                      height: _disc,
                      // Decoded at the size it is drawn at. Google serves a
                      // picture far larger than 36px, and the whole of it
                      // would otherwise sit in the image cache to be drawn
                      // into a disc the size of a fingernail.
                      cacheWidth:
                          (_disc * MediaQuery.devicePixelRatioOf(context))
                              .round(),
                      // Square, whatever Google returns: a picture cropped to
                      // the disc beats one letterboxed inside it.
                      fit: BoxFit.cover,
                      // The mark holds the disc until the picture is drawn,
                      // and keeps it if the picture never arrives. This is
                      // the one thing on the screen that goes to the network
                      // to be drawn, so it has to be allowed to simply not.
                      frameBuilder: (context, child, frame, _) =>
                          frame == null ? mark : child,
                      errorBuilder: (context, error, stack) => mark,
                    ),
                  ),
                },
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    who,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: atItsWeight(
                      theme.textTheme.bodyMedium?.copyWith(
                        color: colours.onSurface,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (behind != null) ...[
                    const SizedBox(height: 2),
                    // Never wrapped: an address broken across two lines reads
                    // as two addresses.
                    Text(
                      behind,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The way a guest keeps what they have made: the same shape as signing out
/// beside it, because both are ways out of being a guest, with the sentence
/// under it saying what happens if it is declined. The label alone does not.
///
/// Drawn only for a guest. An account holder is not offered what they have.
class _KeepThisLedger extends StatelessWidget {
  const _KeepThisLedger({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final words = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return BlocBuilder<TradingAGuestForAnAccount, Trade>(
      builder: (context, trade) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // The spinner takes the button's slot at the button's height, so
            // the sentence under it and the row under that do not move.
            if (trade is Linking)
              SizedBox(
                height: 48,
                child: Center(
                  child: SizedBox.square(
                    dimension: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      semanticsLabel: words.signInInFlight,
                    ),
                  ),
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onPressed,
                  style: asTheWayRound(theme),
                  icon: const Icon(Icons.login, size: 18),
                  label: Text(cased(words, words.settingsKeepThisLedger)),
                ),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                words.settingsKeepThisLedgerHint,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            if (trade is TradeRefused)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Semantics(
                  // Announced when it appears, so a screen reader is not left
                  // to hunt for what changed.
                  liveRegion: true,
                  child: Text(
                    trade.detail,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The Ledger's small FAB stretched to the height of Review's commit button,
/// and then muted: signing out is a way out of the screen rather than what the
/// screen is for, so it is outlined where the one action a screen exists for
/// is filled.
class _SignOut extends StatelessWidget {
  const _SignOut({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final words = AppLocalizations.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: OutlinedButton.icon(
        onPressed: onPressed,
        style: asTheWayRound(Theme.of(context)),
        icon: const Icon(Icons.logout, size: 18),
        label: Text(cased(words, words.settingsSignOut)),
      ),
    );
  }
}
