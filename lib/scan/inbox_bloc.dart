import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:where_money_core/where_money_core.dart';

import '../data/scan_store.dart';
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

/// The user asking for a Scan to be read again, rather than waiting on the
/// background schedule. Refused for a Scan the Model has already read.
final class ScanReadAgain extends InboxEvent {
  const ScanReadAgain(this.scanId);

  final String scanId;

  @override
  List<Object?> get props => [scanId];
}

final class _ReadAgainDue extends InboxEvent {
  const _ReadAgainDue();
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
  InboxBloc(
    this._scans,
    this._model, {
    Knobs knobs = const Knobs(),
    Duration readAgainAfter = _defaultWait,
    this.language = defaultLanguage,
  }) : _longEdge = knobs.longEdge,
       _firstWait = readAgainAfter,
       _wait = readAgainAfter,
       super(const InboxLoading()) {
    on<InboxOpened>(_onOpened);
    on<ScanCaptured>(_onCaptured);
    on<ScanAbandoned>((event, emit) => _scans.abandon(event.scanId));
    on<ScanReadAgain>(_onReadAgain);
    on<_ReadAgainDue>(_onReadAgainDue);
    on<_InboxChanged>((event, emit) {
      emit(InboxReady(event.scans));
      event.scans.where(_waitingToBeRead).forEach(_read);
      _scheduleReadAgain(event.scans);
    });
  }

  /// How long a Scan with no signal waits before it goes round again. The
  /// wait doubles while the signal stays gone, up to [_longestWaitMultiple]
  /// times this, so a phone in a basement settles down to one attempt every
  /// couple of minutes instead of hammering. An attempt that reaches nothing
  /// costs nothing, which is what makes the short first wait affordable.
  static const _defaultWait = Duration(seconds: 15);
  static const _longestWaitMultiple = 8;

  final ScanStore _scans;
  final ModelGateway _model;

  /// The language the Model is asked to write its own words in — the reason it
  /// gives for a Category, and anything it wants Reviewed. Nothing chooses it
  /// yet; pinning it here is how a Chinese Extraction can be watched arriving
  /// under an English Inbox.
  final String language;

  final int _longEdge;
  final Duration _firstWait;
  StreamSubscription<List<Scan>>? _watching;
  Timer? _nextSweep;
  Duration _wait;

  /// Scans this bloc has taken responsibility for, so a Scan is not sent twice
  /// when the Inbox re-reads while it is still in flight.
  final _claimed = <String>{};

  /// One Scan at a time. Nothing forces this, but a wallet emptied in one
  /// sitting would otherwise open a dozen calls at once against an allowance
  /// that only counts up.
  var _reading = Future<void>.value();

  void _onOpened(InboxOpened event, Emitter<InboxState> emit) {
    _watching?.cancel();
    _watching = _scans.inbox().listen((scans) => add(_InboxChanged(scans)));
  }

  /// Nothing here can fail in a way worth telling the user about: it touches
  /// no network, which is what makes a plane and a basement behave the same as
  /// anywhere else. The Scan is durable before this answers.
  Future<void> _onCaptured(ScanCaptured event, Emitter<InboxState> emit) async {
    await _scans.capture(await _resized(event.photograph, _longEdge));
  }

  /// A Scan still at `extracting` that this bloc never claimed was left there
  /// by an app that died mid-read. There is nothing running to wait for, so it
  /// goes round again — the worst case is a receipt read twice.
  bool _waitingToBeRead(Scan scan) =>
      (scan.state == ScanState.captured ||
          scan.state == ScanState.extracting) &&
      !_claimed.contains(scan.id);

  /// A Scan the user asked for again, or one waiting on a signal. Both go
  /// through [_read], so a Scan already in flight is not sent twice however
  /// many times the button is tapped.
  void _onReadAgain(ScanReadAgain event, Emitter<InboxState> emit) {
    if (state case InboxReady(:final scans)) {
      final scan = scans.where((held) => held.id == event.scanId).firstOrNull;
      if (scan != null && scan.canBeReadAgain) _read(scan);
    }
  }

  /// One Scan per sweep. A wallet's worth of receipts stuck behind the same
  /// dead network would otherwise spend an attempt each every time this fires;
  /// the oldest goes first, and the rest follow at the short wait once one of
  /// them gets through.
  void _onReadAgainDue(_ReadAgainDue event, Emitter<InboxState> emit) {
    final longest = _firstWait * _longestWaitMultiple;
    _wait = _wait * 2 < longest ? _wait * 2 : longest;

    if (state case InboxReady(:final scans)) {
      final next = scans.where(_waitingForSignal).lastOrNull;
      if (next != null) _read(next);
      _scheduleReadAgain(scans);
    }
  }

  bool _waitingForSignal(Scan scan) =>
      scan.state == ScanState.failed &&
      (scan.failure?.triesAgainByItself ?? false);

  void _scheduleReadAgain(List<Scan> scans) {
    if (!scans.any(_waitingForSignal)) {
      _nextSweep?.cancel();
      _nextSweep = null;
      return;
    }
    if (_nextSweep?.isActive ?? false) return;
    _nextSweep = Timer(_wait, () => add(const _ReadAgainDue()));
  }

  void _read(Scan scan) {
    if (!_claimed.add(scan.id)) return;
    _reading = _reading.then((_) => _extract(scan));
  }

  /// The background job. It emits nothing itself: every step is written to the
  /// store, and the Inbox learns about it the same way the user does.
  Future<void> _extract(Scan scan) async {
    await _scans.put(scan.movedTo(ScanState.extracting));

    final receipt = await _scans.receiptFor(scan.id);
    if (receipt == null) return;

    final answer = await _model.extract(receipt, language: language);
    // Something answered, so there is no longer anything to back off from.
    // The pending sweep goes with it, or the backlog behind this Scan would
    // keep waiting the long wait that has just been proved unnecessary.
    if (answer is! ModelOutOfReach) {
      _wait = _firstWait;
      _nextSweep?.cancel();
    }

    // Abandoning is the user's, and they may have done it while the Model was
    // reading. `put` is what keeps that decision.
    await _scans.put(_after(scan, answer));
    // Held only for the flight. A Scan that has landed is protected by the
    // state it landed in, and letting go is what lets it be read again.
    _claimed.remove(scan.id);
  }

  @override
  Future<void> close() {
    _nextSweep?.cancel();
    _watching?.cancel();
    return super.close();
  }
}

/// Where an answer leaves the Scan. The allowance is not a failure and a photo
/// of a cat is not something to Review; everything else that went wrong is a
/// failure the Scan carries, because the Inbox has different words for each.
Scan _after(Scan scan, ScanAnswer answer) => switch (answer) {
  ModelAnswered(outcome: ExtractionRead(:final extraction)) =>
    extraction.isReceipt
        ? scan.movedTo(ScanState.extracted, extraction: extraction)
        : scan.movedTo(ScanState.notReceipt, extraction: extraction),
  AllowanceSpent(:final resetsAt) => scan.movedTo(
    ScanState.capped,
    allowanceResetsAt: resetsAt,
  ),
  ModelAnswered(outcome: ExtractionRefused()) => _failed(
    scan,
    ScanFailure.refused,
  ),
  ModelAnswered(outcome: ExtractionNoOutput()) => _failed(
    scan,
    ScanFailure.saidNothing,
  ),
  ModelAnswered(outcome: ExtractionMalformed()) => _failed(
    scan,
    ScanFailure.notLegible,
  ),
  ModelOutOfReach() => _failed(scan, ScanFailure.outOfReach),
  ModelUnavailable() => _failed(scan, ScanFailure.modelUnavailable),
  TokenRefused() => _failed(scan, ScanFailure.tokenRefused),
  ImageNotAccepted() => _failed(scan, ScanFailure.imageNotAccepted),
};

Scan _failed(Scan scan, ScanFailure failure) =>
    scan.movedTo(ScanState.failed, failure: failure);

/// Off the main isolate: a 4200x2500 photograph takes 824ms to decode and
/// re-encode, and the user is meant to be photographing the next receipt
/// rather than watching this one.
Future<Uint8List> _resized(Uint8List photograph, int longEdge) =>
    compute(resizeForStorage, (photograph: photograph, longEdge: longEdge));
