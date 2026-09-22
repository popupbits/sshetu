import 'package:flutter/foundation.dart' show TargetPlatform, immutable;

import 'ssh_host.dart';

/// Why a probe could not reach an address.
enum ReachabilityFailure {
  /// Nothing answered inside the probe's timeout — a firewall dropping the
  /// packets, a machine that is off, a route that goes nowhere.
  timedOut,

  /// The machine answered and said nothing listens on that port.
  refused,

  /// The name did not resolve to an address.
  unresolved,

  /// Anything else the network said: no route, network down.
  unreachable,
}

/// What one TCP connect found. Carries no time; the scheduler stamps that.
@immutable
class ProbeOutcome {
  const ProbeOutcome.up(Duration this.latency) : failure = null;

  const ProbeOutcome.down(ReachabilityFailure this.failure) : latency = null;

  /// How long the TCP connect took, when it succeeded.
  final Duration? latency;

  /// Why it failed, when it did.
  final ReachabilityFailure? failure;

  bool get isUp => failure == null;

  @override
  bool operator ==(Object other) =>
      other is ProbeOutcome &&
      other.latency == latency &&
      other.failure == failure;

  @override
  int get hashCode => Object.hash(latency, failure);

  @override
  String toString() =>
      isUp ? 'up(${latency!.inMilliseconds} ms)' : 'down($failure)';
}

/// A probe's outcome and when it was taken.
@immutable
class ProbeResult {
  const ProbeResult(this.outcome, this.checkedAt);

  final ProbeOutcome outcome;
  final DateTime checkedAt;

  @override
  bool operator ==(Object other) =>
      other is ProbeResult &&
      other.outcome == outcome &&
      other.checkedAt == checkedAt;

  @override
  int get hashCode => Object.hash(outcome, checkedAt);
}

/// Where a probe connects: one hostname and port.
///
/// The unit of deduplication. Three saved hosts that are three accounts on
/// one machine are one address, and probing it three times would be three
/// connections in a firewall's rate limit for one piece of information.
@immutable
class ProbeAddress {
  const ProbeAddress(this.hostname, this.port);

  final String hostname;
  final int port;

  /// Names are case-insensitive; `Web.example.com` and `web.example.com` are
  /// one machine and must be one probe.
  String get key => '${hostname.trim().toLowerCase()}:$port';

  @override
  bool operator ==(Object other) => other is ProbeAddress && other.key == key;

  @override
  int get hashCode => key.hashCode;

  @override
  String toString() => key;
}

/// How often the host list re-checks each address.
///
/// Four named steps and no free field: the floor is the point. A server
/// behind `ufw limit` refuses the seventh connection in thirty seconds, and
/// fail2ban counts connections that never authenticate — an interval a user
/// could set to five seconds is a way to lock them out of their own machine.
enum ReachabilityInterval {
  off('off', null),
  seconds30('30s', Duration(seconds: 30)),
  minute1('1m', Duration(minutes: 1)),
  minutes5('5m', Duration(minutes: 5));

  const ReachabilityInterval(this.id, this.period);

  /// The persisted spelling. Stable, unlike an index.
  final String id;

  /// Null for [off].
  final Duration? period;

  /// Nothing is ever probed more often than this, whatever is stored.
  static const Duration minimum = Duration(seconds: 30);

  /// The default where the user has not chosen: 5 min on every platform.
  ///
  /// Not faster on a desktop, where battery is no concern, because the limit
  /// is the server's patience rather than ours. fail2ban's `aggressive` sshd
  /// mode counts a connection closed before the banner ("Did not receive
  /// identification string") as a failure, and its stock maxretry 5 in a
  /// 10 min findtime is crossed by a probe a minute — a default that bans
  /// people from their own servers. 5 min stays under it. Not Off: checks run
  /// only while the list is on screen with the app in front, and anything
  /// stale is checked the moment the list appears, so a slow cadence costs
  /// little freshness, while Off would hide the feature from everyone who
  /// never opens Settings. The faster steps remain a deliberate choice.
  ///
  /// [platform] is kept so a future platform-specific default has one place
  /// to live.
  static ReachabilityInterval defaultFor(TargetPlatform platform) => minutes5;

  /// Null for an unknown or missing id, meaning "the default".
  static ReachabilityInterval? fromId(String? id) {
    for (final value in values) {
      if (value.id == id) return value;
    }
    return null;
  }
}

/// What a host row shows about reachability.
enum HostReachabilityKind {
  /// No indicator: checking is off, or the host is reached through a jump
  /// host and cannot honestly be checked from here.
  hidden,

  /// A session to this host is connected right now — proof without a probe.
  session,

  up,
  down,

  /// Checked addresses only; nothing has been learnt about this one yet.
  unknown,
}

/// A host row's reachability, resolved from everything that decides it.
@immutable
class HostReachability {
  const HostReachability(this.kind, {this.result});

  const HostReachability.hidden() : this(HostReachabilityKind.hidden);

  final HostReachabilityKind kind;

  /// The probe behind [HostReachabilityKind.up] and
  /// [HostReachabilityKind.down].
  final ProbeResult? result;

  /// The rules, in the order they win:
  ///
  ///  1. Checking turned off shows nothing.
  ///  2. A connected session is the best evidence there is, and costs nothing.
  ///  3. A host behind a jump host shows nothing. Probing it from here tests a
  ///     path SSH does not use: the target is usually on a private network
  ///     that is unreachable from this device by design, so the dot would be
  ///     red for a healthy server; and where it did answer, green would say
  ///     nothing about the route through the jump host. Probing the first hop
  ///     instead would only repeat the jump host's own row, which is in the
  ///     list with its own dot — and the row already carries the jump icon.
  ///  4. Otherwise the last probe of its address, or unknown.
  static HostReachability resolve({
    required SshHost host,
    required bool enabled,
    required bool sessionConnected,
    ProbeResult? result,
  }) {
    if (!enabled) return const HostReachability.hidden();
    if (sessionConnected) {
      return const HostReachability(HostReachabilityKind.session);
    }
    if (host.jumpHostId != null) return const HostReachability.hidden();
    if (result == null) {
      return const HostReachability(HostReachabilityKind.unknown);
    }
    return HostReachability(
      result.outcome.isUp ? HostReachabilityKind.up : HostReachabilityKind.down,
      result: result,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is HostReachability && other.kind == kind && other.result == result;

  @override
  int get hashCode => Object.hash(kind, result);
}

/// The address a host is probed at, or null when it is not probed directly.
ProbeAddress? probeAddressOf(SshHost host) {
  if (host.jumpHostId != null) return null;
  if (host.hostname.trim().isEmpty) return null;
  return ProbeAddress(host.hostname, host.port);
}

/// The addresses worth probing, deduplicated.
///
/// Skips hosts behind a jump host (see [HostReachability.resolve]) and any
/// address a connected session already proves: one live session to a machine
/// answers for every saved host on that address.
Set<ProbeAddress> probeTargets(
  Iterable<SshHost> hosts, {
  Set<String> connectedHostIds = const {},
}) {
  final proven = <ProbeAddress>{
    for (final host in hosts)
      if (connectedHostIds.contains(host.id)) ?probeAddressOf(host),
  };
  return {for (final host in hosts) ?probeAddressOf(host)}.difference(proven);
}
