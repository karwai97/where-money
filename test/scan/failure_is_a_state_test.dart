import 'package:flutter_test/flutter_test.dart';
import 'package:where_money/scan/inbox_bloc.dart';
import 'package:where_money/scan/model_gateway.dart';
import 'package:where_money_core/where_money_core.dart';

import '../fakes/fake_model_gateway.dart';
import '../fakes/in_memory_ledger_store.dart';
import 'inbox_bloc_test.dart' show photograph;

/// Nothing that goes wrong with a Scan is a dialog. Each way it can go wrong
/// is a state the Scan sits in, saying which way it was, and each one is
/// asserted here through the faked gateway.
void main() {
  late InMemoryLedgerStore store;
  late FakeModelGateway model;

  setUp(() {
    store = InMemoryLedgerStore();
    model = FakeModelGateway();
  });

  /// Short enough that a test does not wait on it, and the only reason the
  /// bloc takes it as a parameter.
  InboxBloc opened() =>
      InboxBloc(store, model, readAgainAfter: const Duration(milliseconds: 20))
        ..add(const InboxOpened());

  Future<Scan> scanIn(InboxBloc bloc, bool Function(Scan) settled) async {
    final ready = await bloc.stream.firstWhere(
      (state) => state is InboxReady && state.scans.any(settled),
    );
    return (ready as InboxReady).scans.firstWhere(settled);
  }

  Future<Scan> photographed(InboxBloc bloc) async {
    bloc.add(ScanCaptured(photograph(width: 600, height: 800)));
    return scanIn(bloc, (_) => true);
  }

  Future<Scan> readOne(InboxBloc bloc) async {
    final scan = await photographed(bloc);
    return scanIn(
      bloc,
      (waiting) =>
          waiting.id == scan.id &&
          waiting.state != ScanState.captured &&
          waiting.state != ScanState.extracting,
    );
  }

  group('each way a Scan can fail is its own state', () {
    for (final (name, answer, failure) in [
      ('the Model refused', FakeModelGateway.refusal, ScanFailure.refused),
      (
        'reasoning ate the whole output budget',
        FakeModelGateway.silence,
        ScanFailure.saidNothing,
      ),
      (
        'the answer was not the promised JSON',
        FakeModelGateway.gibberish,
        ScanFailure.notLegible,
      ),
      (
        'the network was gone',
        const ModelOutOfReach('SocketException'),
        ScanFailure.outOfReach,
      ),
      (
        'the Model was down at the far end',
        const ModelUnavailable('model_unavailable: upstream refused'),
        ScanFailure.modelUnavailable,
      ),
      (
        'the token was refused',
        const TokenRefused('expired'),
        ScanFailure.tokenRefused,
      ),
      (
        'the image was not accepted',
        const ImageNotAccepted('image_too_large'),
        ScanFailure.imageNotAccepted,
      ),
    ]) {
      test('$name, and the photo is still there', () async {
        model.answer = answer;
        final bloc = opened();

        final scan = await readOne(bloc);

        expect(scan.state, ScanState.failed);
        expect(scan.failure, failure);
        expect(await store.receiptFor(scan.id), isNotNull);
        await bloc.close();
      });
    }

    test('a refusal is not the same news as silence', () async {
      model.answer = FakeModelGateway.refusal;
      final refused = opened();
      final first = await readOne(refused);
      await refused.close();

      store = InMemoryLedgerStore();
      model.answer = FakeModelGateway.silence;
      final silent = opened();
      final second = await readOne(silent);
      await silent.close();

      expect(first.failure, isNot(second.failure));
    });

    test('a photo that is not a receipt is not a failure either', () async {
      model.answer = FakeModelGateway.reading(notAReceiptExtraction);
      final bloc = opened();

      final scan = await readOne(bloc);

      expect(scan.state, ScanState.notReceipt);
      expect(scan.failure, isNull);
      expect(await store.receiptFor(scan.id), isNotNull);
      await bloc.close();
    });

    test(
      'the Model being down is not the same news as having no signal',
      () async {
        model.answer = const ModelUnavailable('model_unavailable');
        final down = opened();
        final first = await readOne(down);
        await down.close();

        store = InMemoryLedgerStore();
        model.answer = const ModelOutOfReach('SocketException');
        final gone = opened();
        final second = await readOne(gone);
        await gone.close();

        expect(first.failure, isNot(second.failure));
      },
    );

    test('the daily cap is not a failure, and says when it resets', () async {
      final resetsAt = DateTime.utc(2026, 8, 26, 16);
      model.answer = AllowanceSpent(resetsAt: resetsAt);
      final bloc = opened();

      final scan = await readOne(bloc);

      expect(scan.state, ScanState.capped);
      expect(scan.failure, isNull);
      expect(scan.allowanceResetsAt, resetsAt);
      await bloc.close();
    });
  });

  group('trying again', () {
    test(
      'a Scan that failed on the network goes round again by itself',
      () async {
        model.answer = const ModelOutOfReach('SocketException');
        final bloc = opened();
        final failed = await readOne(bloc);
        expect(failed.failure, ScanFailure.outOfReach);

        model.answer = FakeModelGateway.reading(cleanExtraction);

        final read = await scanIn(
          bloc,
          (scan) => scan.id == failed.id && scan.state == ScanState.extracted,
        );
        expect(read.extraction?.merchant, cleanExtraction.merchant);
        await bloc.close();
      },
    );

    test('a failure that has already spent an attempt is left alone', () async {
      model.answer = const ModelUnavailable('model_unavailable');
      final bloc = opened();
      await readOne(bloc);

      model.answer = FakeModelGateway.reading(cleanExtraction);
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(store.waiting.single.failure, ScanFailure.modelUnavailable);
      await bloc.close();
    });

    test('a failure the same bytes will never survive is left alone', () async {
      model.answer = const ImageNotAccepted('image_too_large');
      final bloc = opened();
      final failed = await readOne(bloc);

      model.answer = FakeModelGateway.reading(cleanExtraction);
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(store.waiting.single.state, ScanState.failed);
      expect(store.waiting.single.failure, ScanFailure.imageNotAccepted);
      expect(failed.id, store.waiting.single.id);
      await bloc.close();
    });

    test('a failed Scan can be read again on the spot', () async {
      model.answer = FakeModelGateway.refusal;
      final bloc = opened();
      final failed = await readOne(bloc);

      model.answer = FakeModelGateway.reading(cleanExtraction);
      bloc.add(ScanReadAgain(failed.id));

      final read = await scanIn(
        bloc,
        (scan) => scan.id == failed.id && scan.state == ScanState.extracted,
      );
      expect(read.extraction?.merchant, cleanExtraction.merchant);
      await bloc.close();
    });

    test(
      'a capped Scan can be read again once the allowance is back',
      () async {
        model.answer = const AllowanceSpent();
        final bloc = opened();
        final capped = await readOne(bloc);
        expect(capped.state, ScanState.capped);

        model.answer = FakeModelGateway.reading(cleanExtraction);
        bloc.add(ScanReadAgain(capped.id));

        final read = await scanIn(
          bloc,
          (scan) => scan.id == capped.id && scan.state == ScanState.extracted,
        );
        expect(read.state, ScanState.extracted);
        await bloc.close();
      },
    );

    test('a Scan the Model has already read is not read again', () async {
      final bloc = opened();
      final read = await readOne(bloc);
      expect(read.state, ScanState.extracted);

      model.answer = FakeModelGateway.reading(notAReceiptExtraction);
      bloc.add(ScanReadAgain(read.id));
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(store.waiting.single.state, ScanState.extracted);
      expect(
        store.waiting.single.extraction?.merchant,
        cleanExtraction.merchant,
      );
      await bloc.close();
    });

    test('a Scan the user threw away while it was failing does not come '
        'back', () async {
      model.answer = const ModelOutOfReach('SocketException');
      final bloc = opened();
      final failed = await readOne(bloc);

      bloc.add(ScanAbandoned(failed.id));
      model.answer = FakeModelGateway.reading(cleanExtraction);
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(store.waiting, isEmpty);
      await bloc.close();
    });
  });

  /// The gateway promises a typed answer for every failure it knows about, so
  /// `_extract` has no `try` of its own. It is a seam, though, and a caller
  /// that depends on an implementation keeping a promise is a caller that
  /// hangs: a throw used to leave the Scan claimed and at `extracting`, where
  /// the sweep skips it, `canBeReadAgain` refuses it and `_waitingToBeRead`
  /// excludes it. A spinner with no way out until the app restarts.
  group('a read that throws is a state too', () {
    test(
      'it lands somewhere the user can see rather than at extracting',
      () async {
        model.throws = StateError('no token');
        final bloc = opened();

        final scan = await readOne(bloc);

        expect(scan.state, ScanState.failed);
        expect(scan.failure, ScanFailure.modelUnavailable);
        expect(await store.receiptFor(scan.id), isNotNull);
        await bloc.close();
      },
    );

    /// The reading queue is one chain of futures, and `then` on a future that
    /// completed with an error skips its callback. So an unguarded throw did
    /// not strand one Scan — it stopped every Scan behind it, silently and for
    /// the life of the bloc.
    test('the Scan behind it is still read', () async {
      model.throws = StateError('no token');
      final bloc = opened();

      bloc.add(ScanCaptured(photograph(width: 600, height: 800)));
      bloc.add(ScanCaptured(photograph(width: 640, height: 480)));

      final ready = await bloc.stream.firstWhere(
        (state) =>
            state is InboxReady &&
            state.scans.length == 2 &&
            state.scans.every((scan) => scan.state == ScanState.failed),
      );

      expect((ready as InboxReady).scans, hasLength(2));
      await bloc.close();
    });

    /// Belt and braces on the same chain: the failure above is written to the
    /// store, and if even that cannot be written the queue must still survive.
    test(
      'and it survives a store that cannot write the failure down',
      () async {
        model.throws = StateError('no token');
        store.putThrows = StateError('the disk is full');
        final bloc = opened();

        bloc.add(ScanCaptured(photograph(width: 600, height: 800)));
        await Future<void>.delayed(const Duration(milliseconds: 100));

        store.putThrows = null;
        model.throws = null;
        model.answer = FakeModelGateway.reading(cleanExtraction);
        bloc.add(ScanCaptured(photograph(width: 640, height: 480)));

        final read = await scanIn(
          bloc,
          (scan) => scan.state == ScanState.extracted,
        );
        expect(read.extraction?.merchant, cleanExtraction.merchant);
        await bloc.close();
      },
    );

    test('and the user can read it again', () async {
      model.throws = StateError('no token');
      final bloc = opened();
      final failed = await readOne(bloc);
      expect(failed.state, ScanState.failed);

      model.throws = null;
      model.answer = FakeModelGateway.reading(cleanExtraction);
      bloc.add(ScanReadAgain(failed.id));

      final read = await scanIn(
        bloc,
        (scan) => scan.id == failed.id && scan.state == ScanState.extracted,
      );
      expect(read.extraction?.merchant, cleanExtraction.merchant);
      await bloc.close();
    });
  });
}
