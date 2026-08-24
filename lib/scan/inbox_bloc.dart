import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:where_money_core/where_money_core.dart';

import '../data/ledger_store.dart';
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
  InboxBloc(this._store) : super(const InboxLoading()) {
    on<InboxOpened>(_onOpened);
    on<ScanCaptured>(_onCaptured);
    on<ScanAbandoned>((event, emit) => _store.abandon(event.scanId));
    on<_InboxChanged>((event, emit) => emit(InboxReady(event.scans)));
  }

  final LedgerStore _store;
  StreamSubscription<List<Scan>>? _watching;

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

  @override
  Future<void> close() {
    _watching?.cancel();
    return super.close();
  }
}

/// Off the main isolate: a 4200x2500 photograph takes 824ms to decode and
/// re-encode, and the user is meant to be photographing the next receipt
/// rather than watching this one.
Future<Uint8List> _resized(Uint8List photograph) =>
    compute(resizeForStorage, photograph);
