# SSHetu

**SSH client, terminal, SFTP and tunnels for every device.**
From *सेतु* (setu) — a bridge.

SSHetu keeps your servers in one place and connects to them from a phone, a
tablet or a desktop: a real terminal, a file browser over SFTP, port
forwarding, and SSH keys you can generate on the device.

## No backend, no account

There is no SSHetu server, because an app holding the keys to your production
infrastructure has no business keeping a copy of them on someone else's
machine. Hosts, keys, tunnels and known-host pins live in a database on your
device; credentials live in the OS keychain — Keychain, Keystore, DPAPI or
libsecret — and are written nowhere else.

That has two consequences the app handles deliberately rather than ignoring:

- **Getting your setup onto a second device** is a direct transfer over your
  local network. The desktop shows a QR code carrying a single-use secret, the
  phone scans it, and the two talk on a channel sealed with it. Nothing goes
  through a server; the listener is open only while that screen is.
- **There is no free backup.** So there is an explicit one: an encrypted file
  you keep. The passphrase becomes a key via Argon2id (64 MiB, t=3) — a backup
  sits in a cloud folder for years, and PBKDF2 is what a GPU farm eats for
  breakfast — and the body is sealed with XSalsa20-Poly1305.

## What it does

- **Terminal** — a real VT/xterm emulator, with an adjustable grid size and a
  key bar for the modifiers a software keyboard doesn't have
- **SFTP** — browse, upload, download, rename, chmod
- **Tunnels** — local and remote port forwarding
- **Keys** — generate Ed25519 keys on the device, or import the ones you have
- **Import from OpenSSH** — reads `~/.ssh/config` and your existing keys, so
  the first five minutes aren't spent retyping servers you already wrote down.
  It reads and never writes.
- **Password to key, in one step** — install a key on a host you reach with a
  password, then *prove it works over a second, independent connection* before
  the password is deleted. It does not touch `sshd_config`: disabling password
  auth server-side affects every user and every client, and a mistake locks
  people out of a machine that may be in another country.
- **Known-host pinning**, a fingerprint you can check by eye, and an on-device
  diagnostics log that never leaves the device unless you share it

## Platforms

One codebase, adapting by window width rather than by operating system.

| Platform | State |
|---|---|
| macOS | built and driven by hand; the development machine |
| Android | built, installed and connected to a live server |
| iOS | built, installed and connected on a simulator, with a key generated on the device |
| Windows | built and driven on Windows 11; SSH, SFTP and the terminal exercised against a live server |
| Linux | compiles green on CI; **not yet run by a person** |

That last row is deliberate. "Compiles" and "works" are different claims, and
this table says which one each platform has earned.

## Installing

**There is no release yet** — no tag, no store listing. For now, build it
yourself (below), or take a bundle from a CI run: **Actions → a green run →
Artifacts**, which carries one per desktop platform.

On Windows there is an installer:

```sh
powershell -ExecutionPolicy Bypass -File tool\make_installer.ps1 -Build
# -> windows/installer/output/SSHetu-Setup-<version>.exe
```

It is worth using rather than running the loose `.exe`, because it adds the
firewall rule that lets another device reach the transfer listener — an app
cannot grant itself one.

On macOS, `tool/make_dmg.sh` builds a `.dmg` from a release build.

## Building from source

Needs the [Flutter SDK](https://docs.flutter.dev/get-started/install)
(3.47 or newer).

```sh
flutter pub get
flutter run
```

Platform notes worth knowing before the first build:

- **Windows** — Visual Studio needs the **C++ ATL** component. It is not in the
  "Desktop development with C++" workload by default and `flutter doctor` does
  not check for it, so the first build fails on a missing `atlstr.h` that
  nothing warned you about. See [PROJECT.md](PROJECT.md) §12b.
- **Linux** — the plugins need `libsecret-1`, `libsqlite3`, `libjsoncpp` and
  GTK development headers. The exact list is in `.github/workflows/ci.yml`.
- **macOS** — if the build reports "CocoaPods not installed", `pod` is often at
  `/usr/local/bin` and off the default PATH.

## Contributing

**[PROJECT.md](PROJECT.md) is the guide** — architecture, conventions, the
registries you extend instead of editing shared code, and the one import rule
that will bite you. It is written for humans and coding agents alike.

[CONTRIBUTING.md](CONTRIBUTING.md) covers the practical side: the gates your
change has to pass and how to run them.

## Security

Please **do not open a public issue** for a vulnerability — this app holds
people's production credentials. [SECURITY.md](SECURITY.md) has the private
disclosure route and what is in scope.

## Third-party

Package licences are listed in the app itself, under *Settings → About →
Open-source licences*. Two are worth calling out here because a licence page
does not make them obvious:

- **[xterm2](https://github.com/SoFluffyOS/xterm2)** (MIT) — the terminal
  emulator, **vendored and forked** under `packages/xterm2/`. What diverges
  from upstream, and why, is in
  [`packages/xterm2/VENDORED.md`](packages/xterm2/VENDORED.md).
- **[dartssh2](https://pub.dev/packages/dartssh2)** (MIT) — SSH, SFTP and port
  forwarding, in pure Dart.

## Licence

[MIT](LICENSE) — © 2026 PopupBits.

**The code is MIT; the name and the look are not.** "SSHetu", the icon and the
store listings are PopupBits' branding and are not covered by the licence.
Fork it, build it, ship it — please just ship it under your own name, so that
nobody installs something they think came from us.
