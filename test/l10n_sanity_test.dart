import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards against strings that describe the app as unfinished.
///
/// A placeholder outliving the feature it stood for is a specific and
/// embarrassing failure: the Tunnels screen said "Port forwarding is not wired
/// up yet" for several commits *after* port forwarding worked, and it survived
/// two separate merges. Nothing else catches it — the app compiles, the tests
/// pass, and only the screen is wrong.
///
/// It shipped because merging an agent's `app_en.arb` key-by-key has no right
/// default: taking only new keys discards strings they deliberately reworded,
/// and taking theirs on every conflict reverts corrections made since they
/// branched. Both mistakes were made here, in that order. This test does not
/// fix merging; it makes the class of outcome visible.
void main() {
  test('no user-facing string says a shipped feature is unimplemented', () {
    final arb = jsonDecode(
      File('lib/l10n/app_en.arb').readAsStringSync(),
    ) as Map<String, dynamic>;

    const banned = [
      'not wired up',
      'coming soon',
      'not implemented',
      'todo',
      'placeholder',
      'lorem ipsum',
    ];

    final offenders = <String>[];
    arb.forEach((key, value) {
      if (key.startsWith('@') || value is! String) return;
      // The generated placeholder screen beej ships is allowed to say so
      // until it is replaced; everything else is not.
      if (key.startsWith('comingSoon')) return;
      final lower = value.toLowerCase();
      for (final phrase in banned) {
        if (lower.contains(phrase)) offenders.add('$key: "$value"');
      }
    });

    expect(
      offenders,
      isEmpty,
      reason: 'these strings tell the user a feature does not exist',
    );
  });
}
