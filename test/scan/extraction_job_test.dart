import 'package:flutter_test/flutter_test.dart';
import 'package:where_money/scan/inbox_bloc.dart';
import 'package:where_money/scan/model_gateway.dart';
import 'package:where_money_core/where_money_core.dart';

import '../fakes/fake_model_gateway.dart';
import '../fakes/in_memory_ledger_store.dart';
import 'inbox_bloc_test.dart' show photograph;

/// What happens to a Scan between the shutter and the Inbox, asserted as the
/// sequence of states it moves through rather than as anything on a screen.
void main() {
  late InMemoryLedgerStore store;
  late FakeModelGateway model;

  setUp(() {
    store = InMemoryLedgerStore();
    model = FakeModelGateway();
  });

  /// Every state the named Scan has been seen in, in order, with repeats
  /// collapsed — the Inbox re-reads on every change and would otherwise report
  /// the same state twice.
  List<ScanState> journeyOf(InboxBloc bloc, String scanId) {
    final journey = <ScanState>[];
    bloc.stream.listen((state) {
      if (state is! InboxReady) return;
      for (final scan in state.scans) {
        if (scan.id == scanId && journey.lastOrNull != scan.state) {
          journey.add(scan.state);
        }
      }
    });
    return journey;
  }

  Future<Scan> photographed(InboxBloc bloc) async {
    bloc.add(ScanCaptured(photograph(width: 600, height: 800)));
    final ready = await bloc.stream.firstWhere(
      (state) => state is InboxReady && state.scans.isNotEmpty,
    );
    return (ready as InboxReady).scans.single;
  }

  Future<Scan> settled(InboxBloc bloc, String scanId) async {
    final ready = await bloc.stream.firstWhere(
      (state) =>
          state is InboxReady &&
          state.scans.any(
            (scan) =>
                scan.id == scanId &&
                scan.state != ScanState.captured &&
                scan.state != ScanState.extracting,
          ),
    );
    return (ready as InboxReady).scans.firstWhere((scan) => scan.id == scanId);
  }

  Future<Scan> readOne(InboxBloc bloc) async {
    final scan = await photographed(bloc);
    return settled(bloc, scan.id);
  }

  test('the Model is asked to read in the language the app is in', () async {
    final bloc = InboxBloc(store, model, language: 'zh')
      ..add(const InboxOpened());

    await readOne(bloc);

    expect(model.extractedIn, ['zh']);
    await bloc.close();
  });

  test('an app that has not been told a language asks in English', () async {
    final bloc = InboxBloc(store, model)..add(const InboxOpened());

    await readOne(bloc);

    expect(model.extractedIn, ['en']);
    await bloc.close();
  });

  test('a Scan photographed after the language changed is read in the new '
      'one', () async {
    final bloc = InboxBloc(store, model)..add(const InboxOpened());
    await readOne(bloc);

    bloc.add(const InboxLanguageChanged('zh'));
    bloc.add(ScanCaptured(photograph(width: 600, height: 800)));
    await bloc.stream.firstWhere(
      (state) =>
          state is InboxReady &&
          state.scans.length == 2 &&
          state.scans.every((scan) => scan.extraction != null),
    );

    expect(model.extractedIn, ['en', 'zh']);
    await bloc.close();
  });

  test(
    'an Extraction already taken is not read again to translate it',
    () async {
      final bloc = InboxBloc(store, model)..add(const InboxOpened());
      final first = await readOne(bloc);

      bloc.add(const InboxLanguageChanged('zh'));
      await pumpEventQueue();

      expect(model.extractedIn, [
        'en',
      ], reason: 'a second read would spend a Scan on cosmetics');
      expect(
        (bloc.state as InboxReady).scans.single.extraction,
        first.extraction,
      );
      await bloc.close();
    },
  );

  test(
    'a photographed receipt is read without the user waiting on it',
    () async {
      final bloc = InboxBloc(store, model)..add(const InboxOpened());
      model.hold();

      final scan = await photographed(bloc);
      final journey = journeyOf(bloc, scan.id);
      await pumpEventQueue();

      // The photograph is durable and the Inbox already says what it is doing,
      // with the Model still holding the line open.
      expect(journey, [ScanState.extracting]);
      model.release();
      expect((await settled(bloc, scan.id)).state, ScanState.extracted);

      await bloc.close();
    },
  );

  test('what the Model read arrives on the Scan', () async {
    final bloc = InboxBloc(store, model)..add(const InboxOpened());

    final scan = await readOne(bloc);

    expect(scan.extraction?.merchant, 'Village Grocer Bangsar');
    expect(scan.extraction?.total, 44.10);
    await bloc.close();
  });

  test(
    'the receipt the Model is given is the one stored with the Scan',
    () async {
      final bloc = InboxBloc(store, model)..add(const InboxOpened());

      final scan = await readOne(bloc);

      expect(model.sent, await store.receiptFor(scan.id));
      await bloc.close();
    },
  );

  test('a photo the Model says is not a receipt does not become an Extraction '
      'to Review', () async {
    model.answer = FakeModelGateway.reading(notAReceiptExtraction);
    final bloc = InboxBloc(store, model)..add(const InboxOpened());

    expect((await readOne(bloc)).state, ScanState.notReceipt);
    await bloc.close();
  });

  test(
    'the daily allowance being spent is its own state, not a failure',
    () async {
      model.answer = AllowanceSpent(resetsAt: DateTime(2026, 8, 26));
      final bloc = InboxBloc(store, model)..add(const InboxOpened());

      expect((await readOne(bloc)).state, ScanState.capped);
      await bloc.close();
    },
  );

  for (final (name, answer) in [
    ('a refusal', FakeModelGateway.refusal),
    ('silence from the Model', FakeModelGateway.silence),
    ('text that was not the promised JSON', FakeModelGateway.gibberish),
    ('a dead network', const ModelOutOfReach('SocketException')),
    ('a token the Worker will not take', const TokenRefused('expired')),
  ]) {
    test('$name leaves the Scan failed with its photo still there', () async {
      model.answer = answer;
      final bloc = InboxBloc(store, model)..add(const InboxOpened());

      final scan = await readOne(bloc);

      expect(scan.state, ScanState.failed);
      expect(await store.receiptFor(scan.id), isNotNull);
      await bloc.close();
    });
  }

  test('a Scan left half-read by a force-quit is picked up again', () async {
    final first = InboxBloc(store, FakeModelGateway()..hold())
      ..add(const InboxOpened());
    final scan = await photographed(first);
    await pumpEventQueue();
    expect(store.waiting.single.state, ScanState.extracting);
    await first.close();

    final second = InboxBloc(store, model)..add(const InboxOpened());

    expect((await settled(second, scan.id)).state, ScanState.extracted);
    await second.close();
  });

  test('a Scan abandoned while it was being read does not come back', () async {
    model.hold();
    final bloc = InboxBloc(store, model)..add(const InboxOpened());
    final scan = await photographed(bloc);
    await pumpEventQueue();

    bloc.add(ScanAbandoned(scan.id));
    await pumpEventQueue();
    model.release();
    await pumpEventQueue();

    expect(store.waiting, isEmpty);
    expect(await store.receiptFor(scan.id), isNull);
    await bloc.close();
  });

  test('a Scan already read is not read again when the Inbox changes around '
      'it', () async {
    final bloc = InboxBloc(store, model)..add(const InboxOpened());
    final first = await readOne(bloc);
    final journey = journeyOf(bloc, first.id);

    // A second receipt makes the Inbox re-read, which is what would sweep the
    // first one up again if nothing remembered that it was done with.
    bloc.add(ScanCaptured(photograph(width: 600, height: 800)));
    await bloc.stream.firstWhere(
      (state) => state is InboxReady && state.scans.length == 2,
    );
    await pumpEventQueue();

    // Seen sitting at extracted the whole time. Had it been swept up again it
    // would have gone back through extracting.
    expect(journey, [ScanState.extracted]);
    await bloc.close();
  });
}
