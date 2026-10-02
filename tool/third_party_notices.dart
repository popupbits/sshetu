// Generates THIRD_PARTY_NOTICES.md from the resolved dependency graph.
//
//   dart run tool/third_party_notices.dart            # rewrite the file
//   dart run tool/third_party_notices.dart --check     # exit 1 if stale
//
// Nothing is fetched. The inputs are `pubspec.lock` (which package, which
// version, direct or transitive, runtime or dev) and `.dart_tool/
// package_config.json` (where each one is unpacked on this machine), so the
// licence text read is the licence text that was compiled in. Run
// `flutter pub get` first.
//
// Why a file at all, when the app already ships an in-app licence page:
// LicenseRegistry serves the person who installed the app, and only for
// packages Flutter's own collector can see. This serves the person reading
// the repository before they depend on it, and it is the artefact a licence
// review asks for.

import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  final root = Directory.current;
  final lock = File('${root.path}/pubspec.lock');
  final config = File('${root.path}/.dart_tool/package_config.json');

  if (!lock.existsSync() || !config.existsSync()) {
    stderr.writeln(
      'run `flutter pub get` first — pubspec.lock or '
      '.dart_tool/package_config.json is missing',
    );
    exit(2);
  }

  final locked = _parseLock(lock.readAsLinesSync());
  final roots = _parseConfig(config.readAsStringSync());

  // `pubspec.lock` marks a package "transitive" whether it was pulled in by a
  // runtime dependency or by a dev one, so the lock alone over-reports: the
  // analyzer arrives under flutter_lints and is not shipped. Walk the graph
  // from the direct runtime dependencies instead.
  final shipped = _reachable(
    locked.values
        .where((p) => p.dependency == 'direct main')
        .map((p) => p.name),
    roots,
  );

  final entries = <_Entry>[];
  for (final p in locked.values) {
    if (!shipped.contains(p.name)) continue;
    if (p.source == 'sdk') continue; // Flutter itself
    final dir = roots[p.name];
    final licence = dir == null ? null : _readLicence(dir);
    entries.add(
      _Entry(
        name: p.name,
        version: p.version,
        direct: p.dependency.startsWith('direct'),
        source: p.source,
        url: p.url,
        licence: licence == null ? 'not found' : _identify(licence),
        licencePath: licence?.path == null
            ? null
            : _relative(licence!.path, root.path),
      ),
    );
  }
  entries.sort((a, b) {
    if (a.direct != b.direct) return a.direct ? -1 : 1;
    return a.name.compareTo(b.name);
  });

  final text = _render(entries);
  final out = File('${root.path}/THIRD_PARTY_NOTICES.md');

  if (args.contains('--check')) {
    final current = out.existsSync() ? out.readAsStringSync() : '';
    if (_body(current) != _body(text)) {
      stderr.writeln(
        'THIRD_PARTY_NOTICES.md is out of date — run:\n'
        '  dart run tool/third_party_notices.dart',
      );
      exit(1);
    }
    stdout.writeln('THIRD_PARTY_NOTICES.md is up to date');
    return;
  }

  out.writeAsStringSync(text);
  final unknown = entries.where((e) => e.licence == 'not found').length;
  final nonPermissive = entries.where((e) => !_permissive(e.licence)).toList();
  stdout.writeln(
    'wrote THIRD_PARTY_NOTICES.md — ${entries.length} shipped '
    'packages, $unknown with no licence file found',
  );
  for (final e in nonPermissive) {
    stdout.writeln('  review: ${e.name} ${e.version} — ${e.licence}');
  }
}

// ---------------------------------------------------------------- parsing

class _Locked {
  _Locked(this.name);
  final String name;
  String dependency = 'transitive';
  String source = 'hosted';
  String version = '';
  String url = '';
}

/// A deliberately small reader for the shape pub writes, rather than a YAML
/// dependency pulled in just for this: two levels of indentation, one scalar
/// per line.
Map<String, _Locked> _parseLock(List<String> lines) {
  final out = <String, _Locked>{};
  _Locked? current;
  var inPackages = false;
  for (final line in lines) {
    if (line.startsWith('packages:')) {
      inPackages = true;
      continue;
    }
    if (!inPackages) continue;
    if (line.isNotEmpty && !line.startsWith(' ')) break; // `sdks:`
    final m = RegExp(r'^  ([A-Za-z0-9_]+):\s*$').firstMatch(line);
    if (m != null) {
      current = _Locked(m.group(1)!);
      out[current.name] = current;
      continue;
    }
    if (current == null) continue;
    final kv = RegExp(r'^\s+([a-z]+):\s*"?([^"]*)"?\s*$').firstMatch(line);
    if (kv == null) continue;
    switch (kv.group(1)) {
      case 'dependency':
        current.dependency = kv.group(2)!;
      case 'source':
        current.source = kv.group(2)!;
      case 'version':
        current.version = kv.group(2)!;
      case 'url':
        current.url = kv.group(2)!;
    }
  }
  return out;
}

Map<String, Directory> _parseConfig(String json) {
  final data = jsonDecode(json) as Map<String, dynamic>;
  final out = <String, Directory>{};
  for (final p in (data['packages'] as List).cast<Map<String, dynamic>>()) {
    final uri = Uri.parse(p['rootUri'] as String);
    final dir = uri.scheme == 'file'
        ? Directory.fromUri(uri)
        : Directory('${Directory.current.path}/.dart_tool/${uri.toFilePath()}');
    out[p['name'] as String] = dir;
  }
  return out;
}

/// Everything reachable from [seeds] through the `dependencies:` blocks of
/// the resolved packages — i.e. what actually ends up in the app, as opposed
/// to what pub happened to download.
Set<String> _reachable(Iterable<String> seeds, Map<String, Directory> roots) {
  final seen = <String>{};
  final queue = [...seeds];
  while (queue.isNotEmpty) {
    final name = queue.removeLast();
    if (!seen.add(name)) continue;
    final dir = roots[name];
    if (dir == null) continue;
    for (final candidate in [
      File('${dir.path}/pubspec.yaml'),
      File('${dir.parent.path}/pubspec.yaml'),
    ]) {
      if (!candidate.existsSync()) continue;
      queue.addAll(_runtimeDepsOf(candidate.readAsLinesSync()));
      break;
    }
  }
  return seen;
}

/// The names under a pubspec's `dependencies:` block, ignoring
/// `dev_dependencies:` and `dependency_overrides:`.
Iterable<String> _runtimeDepsOf(List<String> lines) sync* {
  var inBlock = false;
  for (final line in lines) {
    if (line.startsWith('dependencies:')) {
      inBlock = true;
      continue;
    }
    if (line.isNotEmpty && !line.startsWith(' ') && !line.startsWith('#')) {
      inBlock = false;
      continue;
    }
    if (!inBlock) continue;
    final m = RegExp(r'^  ([A-Za-z0-9_]+):').firstMatch(line);
    if (m != null) yield m.group(1)!;
  }
}

const _licenceNames = [
  'LICENSE',
  'LICENSE.md',
  'LICENSE.txt',
  'LICENCE',
  'COPYING',
  'OFL.txt',
];

File? _readLicence(Directory dir) {
  for (final name in _licenceNames) {
    final f = File('${dir.path}/$name');
    if (f.existsSync()) return f;
    // A package's rootUri points at its lib/ parent; pub-cache layout puts
    // the licence beside pubspec.yaml, which is the same place.
    final up = File('${dir.parent.path}/$name');
    if (up.existsSync()) return up;
  }
  return null;
}

/// Names the licence from its text. Deliberately conservative: an
/// unrecognised one is reported as "see file" rather than guessed, because a
/// wrong name in a notices file is worse than no name.
String _identify(File f) {
  final head = f.readAsStringSync();
  final t = head.replaceAll(RegExp(r'\s+'), ' ');
  if (t.contains('Apache License') && t.contains('Version 2.0')) {
    return 'Apache-2.0';
  }
  if (t.contains('SIL OPEN FONT LICENSE')) return 'OFL-1.1';
  if (t.contains('Mozilla Public License')) return 'MPL-2.0';
  if (t.contains('GNU GENERAL PUBLIC LICENSE')) return 'GPL — REVIEW';
  if (t.contains('GNU LESSER GENERAL PUBLIC')) return 'LGPL — REVIEW';
  if (t.contains('Permission is hereby granted, free of charge')) return 'MIT';
  if (t.contains('Redistribution and use in source and binary forms')) {
    if (t.contains('Neither the name')) return 'BSD-3-Clause';
    return 'BSD-2-Clause';
  }
  if (t.contains('Unlicense') || t.contains('public domain')) {
    return 'Unlicense/public domain';
  }
  if (t.contains('ZLIB') || t.contains('zlib License')) return 'Zlib';
  return 'see file';
}

bool _permissive(String licence) => const {
  'MIT',
  'BSD-2-Clause',
  'BSD-3-Clause',
  'Apache-2.0',
  'OFL-1.1',
  'Unlicense/public domain',
  'Zlib',
}.contains(licence);

String _relative(String path, String root) {
  // `package_config.json` points a path dependency at `.dart_tool/../…`, so
  // the `..` has to be collapsed before the prefix test can match.
  final p = Uri.file(path).normalizePath().toFilePath().replaceAll('\\', '/');
  final r = Uri.file(root).normalizePath().toFilePath().replaceAll('\\', '/');
  return p.startsWith(r) ? p.substring(r.length + 1) : p;
}

// ---------------------------------------------------------------- output

class _Entry {
  _Entry({
    required this.name,
    required this.version,
    required this.direct,
    required this.source,
    required this.url,
    required this.licence,
    required this.licencePath,
  });
  final String name;
  final String version;
  final bool direct;
  final String source;
  final String url;
  final String licence;
  final String? licencePath;

  String get home => switch (source) {
    'hosted' => '${url.isEmpty ? "https://pub.dev" : url}/packages/$name',
    'path' => licencePath ?? 'in this repository',
    _ => source,
  };
}

/// The comparison used by `--check`, with the generated-on line removed so a
/// re-run on a different day is not a diff.
String _body(String s) =>
    s.split('\n').where((l) => !l.startsWith('_Generated ')).join('\n');

String _render(List<_Entry> entries) {
  final b = StringBuffer();
  b.writeln('# Third-party notices');
  b.writeln();
  b.writeln('SSHetu is MIT (see [LICENSE](LICENSE)). It is built on the');
  b.writeln('packages below, each under its own licence. This file is');
  b.writeln('generated — run `dart run tool/third_party_notices.dart` after');
  b.writeln('changing a dependency, and `--check` to fail a build on a stale');
  b.writeln('one.');
  b.writeln();
  b.writeln('_Generated from `pubspec.lock`; dev-only dependencies are not');
  b.writeln('listed because they are not shipped._');
  b.writeln();

  b.writeln('## Bundled in the repository');
  b.writeln();
  b.writeln('These are redistributed as files here, not fetched at build');
  b.writeln('time, so their licence text travels with this repository.');
  b.writeln();
  b.writeln('| What | Upstream | Licence | Text |');
  b.writeln('| --- | --- | --- | --- |');
  b.writeln(
    '| `packages/xterm2/` — vendored fork of xterm2 5.3.0 | '
    '<https://github.com/SoFluffyOS/xterm2> | MIT, © 2020 xuty | '
    '[`packages/xterm2/LICENSE`](packages/xterm2/LICENSE) |',
  );
  b.writeln(
    '| Inter — the UI face | <https://github.com/rsms/inter> | OFL-1.1 | '
    '[`assets/fonts/inter/OFL.txt`](assets/fonts/inter/OFL.txt) |',
  );
  b.writeln(
    '| JetBrains Mono | '
    '<https://github.com/JetBrains/JetBrainsMono> | OFL-1.1 | '
    '[`assets/fonts/jetbrains_mono/OFL.txt`]'
    '(assets/fonts/jetbrains_mono/OFL.txt) |',
  );
  b.writeln(
    '| Fira Code | <https://github.com/tonsky/FiraCode> | OFL-1.1 | '
    '[`assets/fonts/fira_code/OFL.txt`](assets/fonts/fira_code/OFL.txt) |',
  );
  b.writeln(
    '| Source Code Pro | '
    '<https://github.com/adobe-fonts/source-code-pro> | OFL-1.1 | '
    '[`assets/fonts/source_code_pro/OFL.txt`]'
    '(assets/fonts/source_code_pro/OFL.txt) |',
  );
  b.writeln(
    '| IBM Plex Mono | <https://github.com/IBM/plex> | OFL-1.1 | '
    '[`assets/fonts/ibm_plex_mono/OFL.txt`]'
    '(assets/fonts/ibm_plex_mono/OFL.txt) |',
  );
  b.writeln();
  b.writeln('The five font licences are also registered with Flutter at');
  b.writeln('startup (`lib/core/theme/terminal_fonts.dart`), so the OFL text');
  b.writeln("travels with the installed app as the licence asks, and shows");
  b.writeln('under *Settings → About → Open-source licences*.');
  b.writeln();

  void table(String heading, Iterable<_Entry> rows, String blurb) {
    b.writeln('## $heading');
    b.writeln();
    b.writeln(blurb);
    b.writeln();
    b.writeln('| Package | Version | Licence | Source |');
    b.writeln('| --- | --- | --- | --- |');
    for (final e in rows) {
      b.writeln('| `${e.name}` | ${e.version} | ${e.licence} | ${e.home} |');
    }
    b.writeln();
  }

  table(
    'Direct dependencies',
    entries.where((e) => e.direct),
    'Declared in `pubspec.yaml`.',
  );
  table(
    'Transitive dependencies',
    entries.where((e) => !e.direct),
    'Pulled in by the packages above. Listed for completeness; each one '
        'ships its own licence, which Flutter also collects into the in-app '
        'licence page.',
  );

  final review = entries.where((e) => !_permissive(e.licence)).toList();
  b.writeln('## Needs a human');
  b.writeln();
  if (review.isEmpty) {
    b.writeln(
      'None. Every shipped package resolves to a permissive licence '
      '(MIT, BSD, Apache-2.0, OFL or public domain), all of which allow '
      'redistribution inside an MIT-licensed app.',
    );
  } else {
    b.writeln(
      'The generator could not place these, or placed them as '
      'something that is not plainly compatible with shipping inside an '
      'MIT app. Read each one; the conclusions reached so far are in '
      '[OPEN_SOURCE_READINESS.md](OPEN_SOURCE_READINESS.md) § '
      '*Third-party licences*.',
    );
    b.writeln();
    for (final e in review) {
      b.writeln(
        '- `${e.name}` ${e.version} — ${e.licence}'
        '${e.licencePath == null ? " (no licence file found)" : ""}',
      );
    }
  }
  b.writeln();
  return b.toString();
}
