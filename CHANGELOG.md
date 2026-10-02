# Changelog

All notable changes to SSHetu are recorded here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and the project follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Store release notes are generated from this file by hand, not automatically —
`android/fastlane/metadata/android/<locale>/changelogs/<versionCode>.txt` for
Play and `ios/fastlane/metadata/en-US/release_notes.txt` for the App Store.
Both have their own length limits, so they are a summary of a section here
rather than a copy of it.

## [Unreleased]

Nothing yet.

## [1.0.0] - 2026-10-02

First release. There is no previous version to compare against, so this
section describes what the app is rather than what changed.

SSHetu is an SSH client: a terminal, a file browser over SFTP, port
forwarding, and the keys and hosts that go with them, on Android, iOS, macOS,
Windows and Linux. There is no SSHetu account and no SSHetu server.

### Added

- **Hosts.** A list of the servers you connect to, with groups, tags and
  per-host settings. Hosts can be reached through a jump host, and the list
  can check reachability in the background without ever signing in.
- **Terminal.** A VT/xterm emulator with an adjustable grid, find, adjustable
  font size and cursor shape, and a key bar carrying the modifiers a software
  keyboard does not have.
- **Sessions survive a dropped connection through tmux.** When the server has
  tmux, each tab runs inside it, so a lost connection picks up where it left
  off instead of losing what was running. It is a per-host setting, and the
  app offers to install tmux on a server that lacks it — with the exact
  command shown first, run on the server, never on the device.
- **Reopen tabs on launch**, reattaching the sessions still running on the
  server.
- **SFTP with a remote text editor.** Browse, upload, download, rename and
  chmod, and open a remote file in an editor that detects a conflicting save
  rather than overwriting it.
- **Tunnels.** Local and remote port forwards, saved, started and stopped from
  a list, with the far end monitored while they run.
- **Keys.** Generate Ed25519 (or ECDSA P-256/P-384, or RSA 3072/4096) on the
  device, or import OpenSSH, PEM and PuTTY keys you already have.
- **Password to key, in one step.** Install a key on a host you currently
  reach with a password, prove it works over a second, independent
  connection, and only then delete the stored password. It does not touch
  `sshd_config`.
- **Import from OpenSSH.** Reads `~/.ssh/config`, your keys and your
  known_hosts, so the first five minutes are not spent retyping servers you
  already wrote down. It reads and never writes.
- **Snippets.** Commands you run often, with placeholders that ask for a value
  or fill one in from the session, inserted or run in any open tab.
- **Command palette.** One search across servers, tabs, snippets and actions.
- **Server info panel** with the stats of the machine you are connected to.
- **Session logging**, off by default, written to a folder you pick, never
  sent anywhere.
- **App lock.** A fingerprint, your face or the device PIN before a saved
  password or key is used. Off by default.
- **Encrypted backup.** One file you keep, sealed with a passphrase through
  Argon2id (64 MiB, t=3) and XSalsa20-Poly1305.
- **Send to a device.** Move your setup to a second device directly over the
  local network: one shows a QR code carrying a single-use secret, the other
  scans it, and the channel is sealed with it. Nothing passes through a
  server.
- **Nepali**, alongside English, throughout the app.
- **Desktop workspace.** On a desktop-sized window, tabs with split panes,
  optional typing into every pane of a split at once, and keyboard shortcuts.
- **MCP server for AI assistants**, desktop only and off by default. It binds
  to 127.0.0.1, needs a bearer token, and every action tool asks for approval
  naming the client, the session and the exact text before anything is sent.

### Security

- Credentials live in the operating system's own store — Keychain, Keystore,
  DPAPI or libsecret — and are written nowhere else. Hosts, keys, tunnels and
  known-host pins live in a database on the device.
- Known-host pinning, with a fingerprint you can read and check by eye.
- Agent forwarding is off by default and enabled per host, forwarding only to
  the host you turned it on for.
- On Android, `allowBackup` is off and both cloud backup and device-to-device
  transfer are excluded, so the host database never leaves the device by way
  of a system backup.
- No analytics, no crash reporter and no third-party SDK with a network sink.
  Errors go to a 50-record log on the device, shown at Settings →
  Diagnostics, which you share only if you choose to.

### Known limits

Worth knowing before you install, rather than after.

- **There is no cloud sync, and there will not be one.** An app holding the
  keys to your infrastructure has no business keeping a copy of them on
  someone else's machine. Moving to a second device is the direct local
  transfer above; keeping a copy is the encrypted backup file, which you
  store yourself.
- **The MCP server and split panes are desktop only.** The MCP switch does not
  exist in a mobile build, and split panes need a desktop-sized window.
- **Devanagari in the terminal is drawn imperfectly.** No monospaced
  Devanagari face exists, so Nepali printed by a remote shell is drawn in the
  platform's own proportional face at the cell widths the terminal assigns.
  It is readable; it does not line up. The rest of the app's Nepali is
  unaffected.
- **Linux has never been run by a person.** It compiles on CI and is shipped
  as a bundle from there. Every other platform has been built and driven by
  hand.
- The UI font is fetched from Google Fonts on first launch, so a first run
  with no network draws the interface in a fallback face.

[Unreleased]: https://github.com/popupbits/sshetu/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/popupbits/sshetu/releases/tag/v1.0.0
