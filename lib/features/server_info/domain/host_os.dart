import 'sections.dart';

/// The operating system families a host tile can mark.
///
/// Families, not distributions: Rocky, Alma, CentOS and RHEL are one mark,
/// because to someone scanning a list of servers they are one kind of
/// machine. Anything unrecognised but plainly Linux is [linux]; anything we
/// could not identify at all is [unknown] and draws no mark.
enum OsFamily {
  ubuntu,
  debian,
  fedora,
  rhel,
  arch,
  alpine,
  opensuse,
  freebsd,
  macos,
  windows,
  linux,
  unknown,
}

/// What detection found about a host, as cached per host.
class HostOsInfo {
  const HostOsInfo({required this.family, this.prettyName});

  final OsFamily family;

  /// `Ubuntu 24.04.1 LTS`, `macOS 14.5` — for a tooltip.
  final String? prettyName;

  Map<String, Object?> toJson() => {
    'family': family.name,
    if (prettyName != null) 'name': prettyName,
  };

  /// Null for anything unreadable: a cache entry written by some future
  /// version, or hand-edited, is simply not there rather than an error.
  static HostOsInfo? fromJson(Object? json) {
    if (json is! Map) return null;
    final name = json['family'];
    if (name is! String) return null;
    final family = OsFamily.values.where((f) => f.name == name).firstOrNull;
    if (family == null) return null;
    final pretty = json['name'];
    return HostOsInfo(
      family: family,
      prettyName: pretty is String && pretty.isNotEmpty ? pretty : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is HostOsInfo &&
      other.family == family &&
      other.prettyName == prettyName;

  @override
  int get hashCode => Object.hash(family, prettyName);
}

/// The detection script, fed to `sh -s` like the others.
const String osDetectScript = r'''
echo "@@sshetu:osrelease"
cat /etc/os-release 2>/dev/null || cat /usr/lib/os-release 2>/dev/null
echo "@@sshetu:uname"
uname -s 2>/dev/null
echo "@@sshetu:swvers"
sw_vers 2>/dev/null
''';

/// Asked only when [osDetectScript] got nothing back — which is what a
/// Windows OpenSSH server does, because it has no `sh`. `cmd /c ver` works
/// whether the server's shell is cmd or PowerShell.
const String windowsDetectCommand = 'cmd /c ver';

const _idFamilies = <String, OsFamily>{
  'ubuntu': OsFamily.ubuntu,
  'linuxmint': OsFamily.ubuntu,
  'pop': OsFamily.ubuntu,
  'elementary': OsFamily.ubuntu,
  'debian': OsFamily.debian,
  'raspbian': OsFamily.debian,
  'fedora': OsFamily.fedora,
  'rhel': OsFamily.rhel,
  'centos': OsFamily.rhel,
  'rocky': OsFamily.rhel,
  'almalinux': OsFamily.rhel,
  'ol': OsFamily.rhel,
  'amzn': OsFamily.rhel,
  'arch': OsFamily.arch,
  'archarm': OsFamily.arch,
  'manjaro': OsFamily.arch,
  'endeavouros': OsFamily.arch,
  'alpine': OsFamily.alpine,
  'opensuse': OsFamily.opensuse,
  'opensuse-leap': OsFamily.opensuse,
  'opensuse-tumbleweed': OsFamily.opensuse,
  'sles': OsFamily.opensuse,
  'suse': OsFamily.opensuse,
  'freebsd': OsFamily.freebsd,
};

/// Reads [output] of [osDetectScript] (and, optionally, [windowsOutput] of
/// [windowsDetectCommand]).
///
/// `ID` wins over `ID_LIKE`: Linux Mint is `ID=linuxmint ID_LIKE="ubuntu
/// debian"`, and the first like-name is the closer one. Without os-release,
/// `uname -s` still tells a Mac, a BSD and a Linux apart.
HostOsInfo parseOsDetection(String output, {String? windowsOutput}) {
  final sections = splitSections(output);
  final release = parseKeyValues(sections['osrelease'] ?? const []);
  final pretty =
      _nonEmpty(release['PRETTY_NAME']) ?? _nonEmpty(release['NAME']);
  final id = release['ID']?.toLowerCase();

  OsFamily? family = id == null ? null : _idFamilies[id];
  if (family == null) {
    for (final like in (release['ID_LIKE'] ?? '').toLowerCase().split(
      RegExp(r'\s+'),
    )) {
      family = _idFamilies[like];
      if (family != null) break;
    }
  }

  final uname = firstLine(sections['uname'])?.toLowerCase();
  if (family == null) {
    if (uname == 'darwin') {
      final sw = parseColonValues(sections['swvers'] ?? const []);
      final product = _nonEmpty(sw['ProductName']) ?? 'macOS';
      final version = _nonEmpty(sw['ProductVersion']);
      return HostOsInfo(
        family: OsFamily.macos,
        prettyName: version == null ? product : '$product $version',
      );
    }
    if (uname == 'freebsd') family = OsFamily.freebsd;
    if (uname == 'linux' || (family == null && release.isNotEmpty)) {
      family = OsFamily.linux;
    }
  }
  if (family != null) {
    return HostOsInfo(
      family: family,
      prettyName: pretty ?? (uname == 'freebsd' ? 'FreeBSD' : null),
    );
  }

  final windows = windowsOutput == null
      ? null
      : RegExp(r'Microsoft Windows[^\r\n]*').firstMatch(windowsOutput)?[0];
  if (windows != null) {
    return HostOsInfo(family: OsFamily.windows, prettyName: windows.trim());
  }
  return const HostOsInfo(family: OsFamily.unknown);
}

/// Whether [output] of [osDetectScript] carried anything at all — if not,
/// the host is worth asking the Windows question.
bool osDetectionFoundNothing(String output) {
  final sections = splitSections(output);
  return sections.values.every(
    (lines) => lines.every((line) => line.trim().isEmpty),
  );
}

String? _nonEmpty(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
