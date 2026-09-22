import 'dart:async';
import 'dart:math';

import 'package:sshetu/features/hosts/data/reachability_probe.dart';
import 'package:sshetu/features/hosts/domain/reachability.dart';

/// A probe that records every call and settles only when told to.
class FakeProbe implements ReachabilityProbe {
  final calls = <ProbeAddress>[];
  final _pending = <Completer<ProbeOutcome>>[];

  /// When set, every probe settles at once with this.
  ProbeOutcome? autoReply;

  int get pending => _pending.length;

  @override
  Future<ProbeOutcome> probe(ProbeAddress address) {
    calls.add(address);
    final reply = autoReply;
    if (reply != null) return Future.value(reply);
    final completer = Completer<ProbeOutcome>();
    _pending.add(completer);
    return completer.future;
  }

  void settleNext(ProbeOutcome outcome) =>
      _pending.removeAt(0).complete(outcome);
}

/// A [Random] whose doubles are chosen by the test.
class FixedRandom implements Random {
  FixedRandom(this.value);

  double value;

  @override
  double nextDouble() => value;

  @override
  int nextInt(int max) => 0;

  @override
  bool nextBool() => false;
}
