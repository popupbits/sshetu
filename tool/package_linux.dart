// Turns a built Linux bundle into the two files a Linux user can actually
// take: a tarball and a .deb.
//
//   flutter build linux --release
//   dart run tool/package_linux.dart --version 1.0.0 --build 1
//   # -> dist/sshetu-1.0.0-linux-x64.tar.gz
//   # -> dist/sshetu_1.0.0-1_amd64.deb
//
// The Linux counterpart to tool/make_dmg.sh and tool/make_installer.ps1, and
// plain for the same reason. `flutter build linux` stops at a folder with a
// binary in it: no menu entry, no icon, nothing a package manager can remove
// again. This adds exactly that and nothing else.
//
// The .deb's dependencies are read out of the built binaries by
// dpkg-shlibdeps rather than written down here, because a hand-kept list goes
// stale the moment a plugin picks up a new library — and the failure that
// causes is a missing symbol at startup on someone else's machine.
import 'dart:convert';
import 'dart:io';

const _package = 'sshetu';
const _appId = 'com.popupbits.sshetu';
const _displayName = 'SSHetu';
const _maintainer = 'PopupBits <popupbits@gmail.com>';
const _homepage = 'https://github.com/popupbits/sshetu';
const _summary = 'SSH client and server manager for every device';

/// Used only when dpkg-shlibdeps is unavailable — a build host without
/// dpkg-dev. Every entry is a link-time dependency of a plugin this app uses,
/// read from that plugin's own linux/CMakeLists.txt (the same list whose -dev
/// halves .github/workflows/ci.yml installs).
const _fallbackDepends =
    'libc6, libgtk-3-0, libglib2.0-0, libsecret-1-0, libsqlite3-0';

Future<void> main(List<String> args) async {
  final options = _parse(args);
  final bundle = Directory(options['bundle']!);
  if (!bundle.existsSync()) {
    _fail('no bundle at ${bundle.path} — run: flutter build linux --release');
  }
  if (!File('${bundle.path}/$_package').existsSync()) {
    _fail('no $_package executable in ${bundle.path}');
  }

  final version = options['version']!;
  final build = options['build']!;
  final out = Directory(options['out']!)..createSync(recursive: true);
  final staging = Directory('build/linux/packaging');
  if (staging.existsSync()) staging.deleteSync(recursive: true);
  staging.createSync(recursive: true);

  stdout.writeln(await _tarball(bundle, staging, out, version));
  stdout.writeln(await _deb(bundle, staging, out, version, build));
}

/// A plain tarball of the bundle, for everyone whose distribution is not
/// Debian's. Unpack it anywhere and run the binary inside.
Future<String> _tarball(
  Directory bundle,
  Directory staging,
  Directory out,
  String version,
) async {
  final name = '$_package-$version-linux-x64';
  final root = Directory('${staging.path}/$name')..createSync(recursive: true);
  await _run('cp', ['-a', '${bundle.path}/.', root.path]);
  File('${root.path}/README.txt').writeAsStringSync(_tarballReadme(version));

  final path = '${out.path}/$name.tar.gz';
  _deleteIfPresent(path);
  await _run('tar', ['-czf', path, '-C', staging.path, name]);
  return path;
}

/// A .deb, so the app arrives with a menu entry and an icon and leaves again
/// without a trace. The payload lives under /usr/lib/sshetu with a symlink on
/// PATH, which is where a self-contained bundle belongs: /usr/bin is for
/// executables, not for an executable and the 40 MB of data beside it.
Future<String> _deb(
  Directory bundle,
  Directory staging,
  Directory out,
  String version,
  String build,
) async {
  final root = Directory('${staging.path}/deb');
  final payload = Directory('${root.path}/usr/lib/$_package')
    ..createSync(recursive: true);
  await _run('cp', ['-a', '${bundle.path}/.', payload.path]);

  Directory('${root.path}/usr/bin').createSync(recursive: true);
  Link('${root.path}/usr/bin/$_package')
      .createSync('../lib/$_package/$_package');

  Directory('${root.path}/usr/share/applications').createSync(recursive: true);
  File('${root.path}/usr/share/applications/$_appId.desktop')
      .writeAsStringSync(_desktopEntry());

  final icon = File('assets/icon/$_package.png');
  if (!icon.existsSync()) _fail('no icon at ${icon.path}');
  final size = _pngSize(icon);
  final iconDir = Directory(
    '${root.path}/usr/share/icons/hicolor/${size}x$size/apps',
  )..createSync(recursive: true);
  icon.copySync('${iconDir.path}/$_appId.png');
  // And again in the old place. hicolor only indexes the sizes its
  // index.theme lists, and this icon is 1024px — larger than any of them on
  // an older theme package. /usr/share/pixmaps is the fallback every desktop
  // still checks, at whatever size it finds, so the launcher entry has an
  // icon even where the themed copy is not picked up.
  final pixmaps = Directory('${root.path}/usr/share/pixmaps')
    ..createSync(recursive: true);
  icon.copySync('${pixmaps.path}/$_appId.png');

  final docDir = Directory('${root.path}/usr/share/doc/$_package')
    ..createSync(recursive: true);
  File('${docDir.path}/copyright').writeAsStringSync(_copyright());

  final debianVersion = '$version-$build';
  final control = Directory('${root.path}/DEBIAN')..createSync(recursive: true);
  File('${control.path}/control')
      .writeAsStringSync(_control(debianVersion, await _depends(payload)));

  final path = '${out.path}/${_package}_${debianVersion}_amd64.deb';
  _deleteIfPresent(path);
  // --root-owner-group, or every file in the archive belongs to whoever ran
  // this and the package installs with a build agent's uid baked in.
  await _run('dpkg-deb', ['--build', '--root-owner-group', root.path, path]);
  return path;
}

/// What this build actually links against, asked of dpkg-shlibdeps.
///
/// It wants a source tree to read a package name out of, so it gets a
/// throwaway one. `--ignore-missing-info` keeps a bundled plugin .so that no
/// installed package owns from failing the whole run — those ship inside the
/// bundle and are not a dependency on anything.
Future<String> _depends(Directory payload) async {
  final binaries =
      payload
          .listSync(recursive: true)
          .whereType<File>()
          .map((file) => file.path)
          .where((path) => path.endsWith('.so') || path.endsWith('/$_package'))
          .toList()
        ..sort();

  final work = Directory.systemTemp.createTempSync('shlibdeps');
  try {
    Directory('${work.path}/debian').createSync();
    File('${work.path}/debian/control').writeAsStringSync(
      'Source: $_package\n\nPackage: $_package\nArchitecture: amd64\n',
    );
    final ProcessResult result;
    try {
      result = await Process.run('dpkg-shlibdeps', [
        '-O',
        '--ignore-missing-info',
        ...binaries,
      ], workingDirectory: work.path);
    } on ProcessException catch (error) {
      stderr.writeln(
        'no dpkg-shlibdeps (${error.message}); '
        'falling back to the known dependency list.',
      );
      return _fallbackDepends;
    }
    const prefix = 'shlibs:Depends=';
    final line = '${result.stdout}'
        .split('\n')
        .firstWhere((l) => l.startsWith(prefix), orElse: () => '');
    if (result.exitCode != 0 || line.isEmpty) {
      stderr.writeln(
        'dpkg-shlibdeps produced no dependency line (exit ${result.exitCode}); '
        'falling back to the known list.\n${result.stderr}',
      );
      return _fallbackDepends;
    }
    return line.substring(prefix.length).trim();
  } finally {
    work.deleteSync(recursive: true);
  }
}

String _control(String version, String depends) =>
    'Package: $_package\n'
    'Version: $version\n'
    'Section: net\n'
    'Priority: optional\n'
    'Architecture: amd64\n'
    'Depends: $depends\n'
    'Maintainer: $_maintainer\n'
    'Homepage: $_homepage\n'
    'Description: $_summary\n'
    ' $_displayName is an SSH client: a terminal, a file browser over SFTP,\n'
    ' port forwarding, and the keys and hosts that go with them. Everything\n'
    ' it knows stays on this machine - there is no account and no sync\n'
    ' server.\n';

String _desktopEntry() =>
    '[Desktop Entry]\n'
    'Type=Application\n'
    'Name=$_displayName\n'
    'GenericName=SSH Client\n'
    'Comment=$_summary\n'
    'Exec=$_package %U\n'
    'Icon=$_appId\n'
    'Terminal=false\n'
    'Categories=Network;RemoteAccess;System;TerminalEmulator;\n'
    'Keywords=SSH;SFTP;Terminal;Server;Tunnel;\n'
    // The WM class a Flutter Linux app reports is its binary name. Without
    // this the window does not match its own launcher entry, and the dock
    // shows two icons for one app.
    'StartupWMClass=$_package\n';

String _copyright() {
  final licence = File('LICENSE');
  if (!licence.existsSync()) _fail('no LICENSE at the repo root');
  return 'Upstream-Name: $_displayName\nSource: $_homepage\n\n'
      '${licence.readAsStringSync()}';
}

/// The icon's own size, from its IHDR chunk — rather than a number written
/// here that stops being true the day the icon is redrawn.
int _pngSize(File png) {
  final bytes = png.readAsBytesSync();
  if (bytes.length < 24) _fail('${png.path} is not a PNG');
  final header = bytes.buffer.asByteData();
  final width = header.getUint32(16);
  final height = header.getUint32(20);
  if (width != height) _fail('${png.path} is ${width}x$height, not square');
  return width;
}

Map<String, String> _parse(List<String> args) {
  final options = <String, String>{
    'bundle': 'build/linux/x64/release/bundle',
    'out': 'dist',
    'version': '',
    'build': '',
  };
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (!arg.startsWith('--')) _fail('unexpected argument "$arg"');
    final key = arg.substring(2);
    if (!options.containsKey(key)) _fail('unknown option "$arg"');
    if (++i >= args.length) _fail('$arg needs a value');
    options[key] = args[i];
  }
  for (final required in ['version', 'build']) {
    if (options[required]!.isEmpty) {
      _fail('--$required is required (tool/release_meta.dart prints both)');
    }
  }
  return options;
}

String _tarballReadme(String version) =>
    '$_displayName $version - Linux x86-64\n'
    '\n'
    'Run ./$_package from this folder. It is self-contained apart from the\n'
    'system libraries every GTK app needs: GTK 3, libsecret (where this app\n'
    'keeps its credentials), SQLite and GLib. On Debian and Ubuntu the .deb\n'
    'beside this file installs those for you, with a menu entry and an icon.\n'
    '\n'
    '$_homepage\n';

Future<void> _run(String executable, List<String> arguments) async {
  final ProcessResult result;
  try {
    result = await Process.run(
      executable,
      arguments,
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    );
  } on ProcessException {
    // Nearly always "this is not a Linux machine". Said plainly, because the
    // raw exception is a stack trace ending in process_win.cc.
    _fail('$executable is not on PATH — packaging needs a Linux host.');
  }
  if (result.exitCode != 0) {
    _fail(
      '$executable ${arguments.join(' ')} failed (${result.exitCode})\n'
      '${result.stdout}${result.stderr}',
    );
  }
}

void _deleteIfPresent(String path) {
  final file = File(path);
  if (file.existsSync()) file.deleteSync();
}

Never _fail(String message) {
  stderr.writeln(message);
  exit(1);
}
