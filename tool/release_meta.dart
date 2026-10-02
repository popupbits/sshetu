// What a release is called, and what it says it contains.
//
// One place that reads `pubspec.yaml` and `CHANGELOG.md`, so a tag, an
// artifact's file name and the notes attached to a GitHub release cannot
// disagree with each other or with the app's own About screen.
//
//   dart run tool/release_meta.dart version        -> 1.0.0
//   dart run tool/release_meta.dart build          -> 1
//   dart run tool/release_meta.dart check-tag v1.0.0
//   dart run tool/release_meta.dart notes 1.0.0    -> that CHANGELOG section
//
// Exits non-zero with a message on stderr when something does not line up,
// which is the point: a release that names the wrong version is worse than a
// release that did not happen.
import 'dart:io';

void main(List<String> args) {
  if (args.isEmpty) {
    _fail(
      'usage: release_meta.dart <version|build|check-tag|notes> [argument]',
    );
  }
  switch (args.first) {
    case 'version':
      stdout.writeln(_pubspecVersion().name);
    case 'build':
      stdout.writeln(_pubspecVersion().build);
    case 'check-tag':
      if (args.length < 2) _fail('check-tag needs the tag, e.g. v1.0.0');
      _checkTag(args[1]);
    case 'notes':
      final version = args.length > 1 ? args[1] : _pubspecVersion().name;
      stdout.write(_notes(version));
    default:
      _fail('unknown command "${args.first}"');
  }
}

/// `version: 1.0.0+1` split into its two halves.
({String name, String build}) _pubspecVersion() {
  final file = File('pubspec.yaml');
  if (!file.existsSync()) {
    _fail('no pubspec.yaml — run this from the repo root');
  }
  for (final line in file.readAsLinesSync()) {
    final match = RegExp(r'^version:\s*(\S+)\s*$').firstMatch(line);
    if (match == null) continue;
    final value = match.group(1)!;
    final plus = value.indexOf('+');
    if (plus < 0) _fail('pubspec version "$value" has no +build number');
    return (name: value.substring(0, plus), build: value.substring(plus + 1));
  }
  _fail('no version: line in pubspec.yaml');
}

/// A tag names exactly one version, and it is this one.
///
/// A pre-release suffix is allowed on top of it — `v1.0.0-rc.1` releases the
/// 1.0.0 in pubspec — because that is how a candidate for a version is named.
void _checkTag(String tag) {
  final version = _pubspecVersion().name;
  final stripped = tag.startsWith('v') ? tag.substring(1) : tag;
  final base = stripped.split('-').first;
  if (base != version) {
    _fail(
      'tag $tag does not match pubspec version $version.\n'
      'Either tag v$version, or bump pubspec.yaml first.',
    );
  }
  stdout.writeln('$tag matches pubspec version $version');
}

/// The CHANGELOG section for [version], without its heading.
///
/// Read from the file every release rather than written twice: release notes
/// that were retyped are release notes that drift.
String _notes(String version) {
  final file = File('CHANGELOG.md');
  if (!file.existsSync()) _fail('no CHANGELOG.md');
  final lines = file.readAsLinesSync();
  final heading = RegExp(r'^##\s+\[?' + RegExp.escape(version) + r'\]?(\s|$)');
  var start = -1;
  for (var i = 0; i < lines.length; i++) {
    if (heading.hasMatch(lines[i])) {
      start = i + 1;
      break;
    }
  }
  if (start < 0) _fail('CHANGELOG.md has no section for $version');
  var end = lines.length;
  for (var i = start; i < lines.length; i++) {
    if (lines[i].startsWith('## ')) {
      end = i;
      break;
    }
  }
  final body = lines.sublist(start, end).join('\n').trim();
  if (body.isEmpty) _fail('the $version section of CHANGELOG.md is empty');
  return '$body\n';
}

Never _fail(String message) {
  stderr.writeln(message);
  exit(1);
}
