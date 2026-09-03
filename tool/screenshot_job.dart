// Builds a moksha job file from screenshots/headlines.json.
//
//   dart run tool/screenshot_job.dart \
//     --asset-type android-phone-screenshot \
//     --locale en-US \
//     --captures build/screenshots \
//     --out job.json
//
// Kept in Dart, and separate from the workflow, so the mapping from our copy
// to moksha's config is readable and can be run by hand. `npm run render --
// --schema` in a moksha checkout lists every valid asset type, size, layout
// and frame.

import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  final assetType = _option(args, '--asset-type');
  final locale = _option(args, '--locale') ?? 'en-US';
  final captureDir = _option(args, '--captures') ?? 'build/screenshots';
  final outPath = _option(args, '--out') ?? 'job.json';
  final sizeId = _option(args, '--size-id');

  if (assetType == null) {
    stderr.writeln(
      'usage: --asset-type <id> [--locale en-US] [--size-id <id>] '
      '[--captures <dir>] [--out <file>]',
    );
    exit(64);
  }

  final configFile = File('screenshots/headlines.json');
  if (!configFile.existsSync()) {
    stderr.writeln('missing ${configFile.path}');
    exit(1);
  }
  final config = jsonDecode(configFile.readAsStringSync())
      as Map<String, dynamic>;

  final captures =
      Directory(captureDir)
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.png'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  if (captures.isEmpty) {
    stderr.writeln('no PNGs in $captureDir — capture before building a job');
    exit(1);
  }

  final scenes = [
    for (final scene in (config['scenes'] as List? ?? const []))
      scene as Map<String, dynamic>,
  ];
  final layouts = [
    for (final layout in (config['layouts'] as List? ?? const []))
      layout as String,
  ];
  final fonts = (config['fonts'] as Map?) ?? const {};
  // Per locale, because a font renders the scripts it has glyphs for and
  // silently draws nothing for the rest.
  final font = fonts[locale] ?? fonts['default'] ?? 'Inter';

  final assets = <Map<String, dynamic>>[];

  for (var i = 0; i < captures.length; i++) {
    final name = captures[i].uri.pathSegments.last;
    final id = _sceneId(name);
    final scene = scenes.cast<Map<String, dynamic>?>().firstWhere(
      (s) => s?['id'] == id,
      orElse: () => null,
    );

    if (scene == null) {
      stderr.writeln('no scene "$id" in headlines.json — skipping $name');
      continue;
    }

    final headline = _text(scene['headline'], locale);
    final subhead = _text(scene['subhead'], locale);

    assets.add({
      'assetType': assetType,
      'sizeId': ?sizeId,
      // Cycled rather than fixed: a listing where every tile has the same
      // composition reads as a contact sheet.
      if (layouts.isNotEmpty) 'layout': layouts[i % layouts.length],
      if (config['background'] != null) 'background': config['background'],
      'textOverlays': [
        if (headline.isNotEmpty)
          {
            'text': headline,
            'anchor': 'top-center',
            'fontSize': 0.055,
            'font': font,
            'weight': 800,
          },
        if (subhead.isNotEmpty)
          {
            'text': subhead,
            'anchor': 'top-center',
            'offsetY': 0.075,
            'fontSize': 0.034,
            'font': font,
            'weight': 500,
          },
      ],
      'screenshot': name,
      'filename': name,
    });
  }

  if (assets.isEmpty) {
    stderr.writeln('every capture was skipped; nothing to render');
    exit(1);
  }

  File(outPath).writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert({'assets': assets}),
  );
  stdout.writeln('${assets.length} asset(s) -> $outPath  ($assetType, $locale)');
}

/// `01_home.png` -> `home`. The numeric prefix is capture order, which is also
/// the order the store shows them in.
String _sceneId(String fileName) {
  final withoutExtension = fileName.replaceAll(RegExp(r'\.png$'), '');
  final underscore = withoutExtension.indexOf('_');
  return underscore == -1
      ? withoutExtension
      : withoutExtension.substring(underscore + 1);
}

String _text(Object? value, String locale) =>
    value is Map ? '${value[locale] ?? ''}' : '';

String? _option(List<String> args, String name) {
  final index = args.indexOf(name);
  if (index == -1 || index + 1 >= args.length) return null;
  return args[index + 1];
}
