import 'dart:typed_data';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:where_money/scan/inbox_bloc.dart';
import 'package:where_money_core/where_money_core.dart';

import '../fakes/in_memory_ledger_store.dart';

Uint8List photograph({required int width, required int height}) {
  final canvas = img.Image(width: width, height: height);
  // Something with detail in it, so the JPEG encoder cannot cheat on size.
  for (var y = 0; y < height; y += 7) {
    img.drawLine(
      canvas,
      x1: 0,
      y1: y,
      x2: width,
      y2: y,
      color: img.ColorRgb8(20, 20, 20),
    );
  }
  return img.encodeJpg(canvas);
}

({int width, int height}) sizeOf(Uint8List bytes) {
  final decoded = img.decodeJpg(bytes)!;
  return (width: decoded.width, height: decoded.height);
}

void main() {
  late InMemoryLedgerStore store;

  setUp(() => store = InMemoryLedgerStore());

  blocTest<InboxBloc, InboxState>(
    'the Inbox starts empty and says so rather than spinning forever',
    build: () => InboxBloc(store),
    act: (bloc) => bloc.add(const InboxOpened()),
    expect: () => [isA<InboxReady>().having((s) => s.scans, 'scans', isEmpty)],
  );

  test('a photographed receipt is in the Inbox at captured', () async {
    final bloc = InboxBloc(store)..add(const InboxOpened());
    bloc.add(ScanCaptured(photograph(width: 600, height: 800)));
    final ready = await bloc.stream.firstWhere(
      (state) => state is InboxReady && state.scans.isNotEmpty,
    );

    expect((ready as InboxReady).scans.single.state, ScanState.captured);
    await bloc.close();
  });

  test(
    'the Scan and its image are both stored before capture answers',
    () async {
      final bloc = InboxBloc(store)..add(const InboxOpened());
      bloc.add(ScanCaptured(photograph(width: 600, height: 800)));
      await bloc.stream.firstWhere(
        (state) => state is InboxReady && state.scans.isNotEmpty,
      );

      final scan = (bloc.state as InboxReady).scans.single;
      expect(await store.imageFor(scan.id), isNotNull);
      await bloc.close();
    },
  );

  test('several receipts can be photographed one after another', () async {
    final bloc = InboxBloc(store)..add(const InboxOpened());
    for (var i = 0; i < 5; i++) {
      bloc.add(ScanCaptured(photograph(width: 600, height: 800)));
    }
    final ready = await bloc.stream.firstWhere(
      (state) => state is InboxReady && state.scans.length == 5,
    );

    expect((ready as InboxReady).scans, hasLength(5));
    expect(ready.scans.map((s) => s.id).toSet(), hasLength(5));
    await bloc.close();
  });

  test('the stored image is about 1024px on its long edge', () async {
    final bloc = InboxBloc(store)..add(const InboxOpened());
    bloc.add(ScanCaptured(photograph(width: 2268, height: 3024)));
    await bloc.stream.firstWhere(
      (state) => state is InboxReady && state.scans.isNotEmpty,
    );

    final scan = (bloc.state as InboxReady).scans.single;
    final stored = sizeOf((await store.imageFor(scan.id))!);
    expect(stored.height, 1024);
    expect(stored.width, 768);
    await bloc.close();
  });

  test('a photograph already small enough is stored as it arrived', () async {
    final original = photograph(width: 600, height: 800);
    final bloc = InboxBloc(store)..add(const InboxOpened());
    bloc.add(ScanCaptured(original));
    await bloc.stream.firstWhere(
      (state) => state is InboxReady && state.scans.isNotEmpty,
    );

    final scan = (bloc.state as InboxReady).scans.single;
    expect(await store.imageFor(scan.id), original);
    await bloc.close();
  });

  test(
    'abandoning a Scan takes it out of the Inbox and its image with it',
    () async {
      final bloc = InboxBloc(store)..add(const InboxOpened());
      bloc.add(ScanCaptured(photograph(width: 600, height: 800)));
      await bloc.stream.firstWhere(
        (state) => state is InboxReady && state.scans.isNotEmpty,
      );
      final scan = (bloc.state as InboxReady).scans.single;

      bloc.add(ScanAbandoned(scan.id));
      final emptied = await bloc.stream.firstWhere(
        (state) => state is InboxReady && state.scans.isEmpty,
      );

      expect((emptied as InboxReady).scans, isEmpty);
      expect(await store.imageFor(scan.id), isNull);
      await bloc.close();
    },
  );
}
