import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:where_money_core/where_money_core.dart';

import '../data/ledger_store.dart';
import 'model_gateway.dart';
import 'receipt_image.dart';

sealed class InboxEvent extends Equatable {
  const InboxEvent();

  @override
  List<Object?> get props => const [];
}

final class InboxOpened extends InboxEvent {
  const InboxOpened();
}

/// A photograph, from the camera or the gallery. The widget's whole job is to
/// produce these bytes; everything that happens to them happens here.
final class ScanCaptured extends InboxEvent {
  const ScanCaptured(this.photograph);

  final Uint8List photograph;

  @override
  List<Object?> get props => [photograph];
}

final class ScanAbandoned extends InboxEvent {
  const ScanAbandoned(this.scanId);

  final String scanId;

  @override
  List<Object?> get props => [scanId];
}

final class _InboxChanged extends InboxEvent {
  const _InboxChanged(this.scans);

  final List<Scan> scans;

  @override
  List<Object?> get props => [scans];
}

sealed class InboxState extends Equatable {
  const InboxState();

  @override
  List<Object?> get props => const [];
}

final class InboxLoading extends InboxState {
  const InboxLoading();
}

final class InboxReady extends InboxState {
  const InboxReady(this.scans);

  final List<Scan> scans;

  /// Scans are compared by identity — an Extraction is not Equatable, and a
  /// re-read produces fresh objects — so a change the Inbox should show can
  /// never be mistaken for no change at all.
  @override
  List<Object?> get props => [scans];
}

class InboxBloc extends Bloc<InboxEvent, InboxState> {
  InboxBloc(this._store, this._model) : super(const InboxLoading()) {
    on<InboxOpened>(_onOpened);
    on<ScanCaptured>(_onCaptured);
    on<ScanAbandoned>((event, emit) => _store.abandon(event.scanId));
    on<_InboxChanged>((event, emit) {
      emit(InboxReady(event.scans));
      event.scans.where(_waitingToBeRead).forEach(_read);
    });
  }

  final LedgerStore _store;
  final ModelGateway _model;
  StreamSubscription<List<Scan>>? _watching;

  /// Scans this bloc has taken responsibility for, so a Scan is not sent twice
  /// when the Inbox re-reads while it is still in flight.
  final _claimed = <String>{};

  /// One Scan at a time. Nothing forces this, but a wallet emptied in one
  /// sitting would otherwise open a dozen calls at once against an allowance
  /// that only counts up.
  var _reading = Future<void>.value();

  void _onOpened(InboxOpened event, Emitter<InboxState> emit) {
    _watching?.cancel();
    _watching = _store.inbox().listen((scans) => add(_InboxChanged(scans)));
  }

  /// Nothing here can fail in a way worth telling the user about: it touches
  /// no network, which is what makes a plane and a basement behave the same as
  /// anywhere else. The Scan is durable before this answers.
  Future<void> _onCaptured(ScanCaptured event, Emitter<InboxState> emit) async {
    await _store.capture(await _resized(event.photograph));
  }

  /// A Scan still at `extracting` that this bloc never claimed was left there
  /// by an app that died mid-read. There is nothing running to wait for, so it
  /// goes round again — the worst case is a receipt read twice.
  bool _waitingToBeRead(Scan scan) =>
      (scan.state == ScanState.captured ||
          scan.state == ScanState.extracting) &&
      !_claimed.contains(scan.id);

  void _read(Scan scan) {
    _claimed.add(scan.id);
    _reading = _reading.then((_) => _extract(scan));
  }

  /// The background job. It emits nothing itself: every step is written to the
  /// store, and the Inbox learns about it the same way the user does.
  Future<void> _extract(Scan scan) async {
    await _store.put(scan.movedTo(ScanState.extracting));

    final receipt = await _store.imageFor(scan.id);
    if (receipt == null) return;

    final answer = await _model.extract(receipt);
    // Abandoning is the user's, and they may have done it while the Model was
    // reading. `put` is what keeps that decision.
    await _store.put(_after(scan, answer));
  }

  @override
  Future<void> close() {
    _watching?.cancel();
    return super.close();
  }
}

/// Where an answer leaves the Scan. Ticket 08 owns telling the failures apart
/// on screen; what matters here is that the allowance is not a failure and a
/// photo of a cat is not something to Review.
Scan _after(Scan scan, ModelAnswer answer) => switch (answer) {
  ModelAnswered(outcome: ExtractionRead(:final extraction)) =>
    extraction.isReceipt
        ? scan.movedTo(ScanState.extracted, extraction: extraction)
        : scan.movedTo(ScanState.notReceipt, extraction: extraction),
  AllowanceSpent() => scan.movedTo(ScanState.capped),
  ModelAnswered() ||
  TokenRefused() ||
  ModelOutOfReach() ||
  ImageNotAccepted() => scan.movedTo(ScanState.failed),
};

/// Off the main isolate: a 4200x2500 photograph takes 824ms to decode and
/// re-encode, and the user is meant to be photographing the next receipt
/// rather than watching this one.
Future<Uint8List> _resized(Uint8List photograph) =>
    compute(resizeForStorage, photograph);
