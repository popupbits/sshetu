# SSHetu privacy policy

**This file is a draft, and a draft is not a privacy policy.** Both stores
require a policy at a public `https://` URL — a page, not a PDF, not
geofenced, reachable without logging in. Until this text is hosted somewhere
and that URL is entered in the Play Console and in App Store Connect, SSHetu
cannot be submitted to either store. See `RELEASE_READINESS.md`.

When it is hosted, put the same URL in three places: the Play Console listing,
App Store Connect, and the app's About screen.

---

*Last updated: 22 September 2026*

## The short version

SSHetu does not collect anything. There is no account, no server of ours, and
no analytics. Your servers, your keys and your passwords are stored on your
own device and are sent nowhere except to the servers you yourself connect to.

## Who this is about

SSHetu ("the app") is an SSH client and server manager published by PopupBits
("we"). It runs on Android, iOS, macOS, Windows and Linux.

## What the app stores, and where

Everything the app knows about you lives on the device you installed it on.

| What | Where it is kept |
| --- | --- |
| Hosts, groups, tags, notes, tunnels, snippets, known-host fingerprints | A SQLite database in the app's own storage |
| Passwords, private keys, key passphrases | The operating system's credential store — Android Keystore / iOS and macOS Keychain / Windows DPAPI / libsecret on Linux |
| Settings: theme, accent, language, text size, terminal preferences | The platform's own preferences store |
| The diagnostics log (errors the app caught) | The app's own preferences, capped at 50 records |
| Session logs, if you turn them on | A file, in a folder you choose |
| Encrypted backups, if you make one | A file you choose, encrypted with your passphrase |

None of it is transmitted to us. We have no way to read any of it, because
there is nowhere for it to go: the app has no backend.

## What leaves your device

Three things, and nothing else.

**1. Your SSH connections.** When you connect to a server, the app talks to
that server — the one whose address you typed. What you send and what it sends
back travels over the SSH connection, encrypted end to end, and passes through
no system of ours. The same applies to SFTP transfers and port forwards.

**2. Device-to-device transfer, when you start one.** "Send to a device" opens
a direct connection between your two devices over your own local network,
sealed with a single-use secret carried in the QR code you scan. The data goes
from one of your devices to the other. It does not pass through any server,
ours or anyone else's, and the listener is open only while that screen is.

**3. Google Play, on Android.** The Android build asks Google Play whether a
newer version of the app exists, and can show Play's own "rate this app" sheet.
Both are Google Play services on your device; they tell Play which app asked,
not who you are or what is in it. They do not run on any other platform.

## What we collect

Nothing. We operate no server, run no analytics, use no advertising or
attribution SDK, and there is no crash reporting that sends anything anywhere.
Errors the app catches are written to a log on the device that only you can
see, under Settings → Diagnostics. Sharing it is an action you take
deliberately, to whoever you choose.

There is no account, so there is nothing to delete on our side and no account
deletion to request. Uninstalling the app removes the database and the
settings; credentials stored in the operating system's credential store are
removed with them.

## Permissions, and why

- **Internet / network access** — to reach the servers you connect to. Without
  it the app does nothing at all.
- **Local network access** (iOS and macOS) — to reach servers on your own
  network, and for the device-to-device transfer.
- **Camera** — only to scan the QR code shown by your other device during a
  transfer. The camera opens when you open the scanner and never otherwise, no
  image is stored, and you can paste the code as text instead.
- **Biometrics / Face ID** — only if you turn on the credential lock, to
  confirm it is you before a saved password or key is used. The check happens
  on the device; no biometric data reaches the app.
- **Notifications and background running** (Android) — to show the notification
  that keeps your open sessions and tunnels alive while you are in another
  app, with a "Disconnect all" action. It runs only while a connection you
  opened is active, and you can turn it off in Settings.
- **Files you pick** — to import an OpenSSH config or key, or to save a backup
  or a session log. The app reads and writes only what you choose in the file
  picker.

## Letting an AI assistant use the app

On desktop only, and off unless you turn it on, SSHetu can run a local server
that lets an AI assistant running on the same computer use the app (Settings →
Integrations). It listens on `127.0.0.1` only — nothing outside that computer
can reach it — and every action that changes anything asks you first, naming
the client, the exact command and the exact session. Read requests never leave
the computer. No part of this sends anything to us.

Note that the assistant you connect is a separate product with its own privacy
policy. What you approve it to read or run, it may send to whoever operates it.
That is a decision you make each time the dialog appears.

## Children

SSHetu is a developer tool. It is not directed at children and we do not
knowingly collect anything from anyone, of any age.

## Changes

If this policy changes, the date at the top changes with it. Material changes
will also be noted in the app's release notes.

## Contact

<!-- TODO(owner): a real contact address, and the hosted URL of this page.
     Apple rejects a mailto: as a Support URL, so the support page and this
     policy both need to be real pages. -->
