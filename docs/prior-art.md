# Prior art, and the decisions that came out of it

Surveyed 2026-09-03, before any SSH code was written. This exists so the next
person does not re-run the same survey — and so the decisions below can be
argued with on the evidence, not re-litigated from scratch.

## The terminal package

| Package | State | Verdict |
| --- | --- | --- |
| `xterm` (TerminalStudio/xterm.dart) | 4.0.0, Feb 2024. Last push June 2025, 107 open issues, 2 commits in all of 2025. | Dead. This is what karmashala vendored, and why. |
| `xterm2` (SoFluffyOS) | 5.3.0, active. Community fork of the above. Small — 4 stars — so single-maintainer risk is real. | **Chosen**, vendored. |

xterm2 brings, over xterm 4.0.0: DEC synchronized updates, OSC 8 hyperlinks,
cursor shapes and blink, procedurally drawn box/block/mosaic glyphs (no font
seams), IME composition positioning, a Flutter shortcut system, and measurable
parser/allocation/cell-copy work. Most of that list is *specifically* mobile
and TUI quality, which is this app's whole job.

Karmashala's four patches to xterm 4.0.0 were checked against xterm2 5.3.0 one
by one. Two are still needed and are carried; one is fixed better upstream; one
is deferred pending measurement. The full table, with the reasoning and the
measurements, is in [`packages/xterm2/VENDORED.md`](../packages/xterm2/VENDORED.md).

The two carried patches are real, reproducible bugs in current xterm2, pinned
by `test/terminal/vendored_xterm2_test.dart`, which fails against pristine
upstream. They are worth reporting to xterm2's issue tracker; if they land
there, drop the patch and keep the test.

## The SSH library

`dartssh2` — the only serious pure-Dart option, and it moved: maintenance
passed from TerminalStudio to `vicajilau`, and **4.0.0 shipped 2026-08-31**.
Karmashala is still on 3.3.1. We start on 4.0.0.

What 4.0.0 changes that matters here:

- **SHA-1 key exchange, `ssh-rsa` host keys and CBC ciphers are out of the
  defaults.** A server offering nothing else now fails to negotiate rather than
  connecting weakly. Old routers, switches and embedded boxes *will* hit this,
  so a per-host "allow legacy algorithms" escape hatch through `SSHAlgorithms`
  is a v1 requirement — per host, never global, and it must say what it costs.
- **A host key that changes during rekey now terminates the connection** with
  `SSHHostkeyError`, as OpenSSH does, and `onVerifyHostKey` is consulted once
  per connection. This strengthens the verifier ported from karmashala rather
  than breaking it.
- SFTP upload now drains in-flight writes and reports the *first* error, not
  whichever arrived last. `chunkSize`/`maxBytesOnTheWire` are deprecated for
  `defaultChunkSize`.
- Reads are EOF-driven, so virtual files (`/proc/...`) no longer come back
  empty — which matters for any "show me system status" feature.

## What shipping SSH clients do

**ConnectBot** (3.4k stars, active) — the open-source Android benchmark. Free,
no account, no cloud, no tiers. No SFTP, dated UI. Does one job well.

**JuiceSSH** — unpublished from the Play Store in December 2025, last release
February 2021. The field it left is the opportunity here.

**Termius** — the commercial target. The features that define the category:
host chains (ProxyJump/bastion), agent forwarding, SFTP, port forwarding,
snippets, mosh, multi-tab and split view, and **import from `~/.ssh/config`**.

**`rudra-sah00/ssh-client`** — a Flutter/dartssh2/xterm client with essentially
our v1 scope. Worth reading for one pattern in particular: a heartbeat, plus
resume-detection, plus **tmux reattach**, to survive Android suspending the app.

## Three things the survey changed our mind about

### 1. Mosh is the real mobile differentiator, and we cannot have it yet

SSH is the protocol that handles phone conditions *worst*: it dies on a radio
hop, on app suspension, on sleep. Mosh was designed for exactly that — UDP
state synchronisation that roams across IP changes, plus predictive local echo
that hides latency. It is why Blink Shell is built on it and why Termius
supports it.

There is no Dart mosh implementation, and writing one is a serious project
(UDP transport, SSP, a predictive echo model). **Not v1.** But the session
layer must be an interface over "a thing that carries bytes and a resize
signal", so mosh can slot in beside SSH later without touching the terminal or
the UI. This is the single most important architectural consequence of the
survey.

### 2. Android will kill the session, and that is a feature we have to build

A backgrounded SSH connection needs a foreground service and a partial wakelock,
and vendor battery managers still interfere. Wakelock alone is not enough. The
cheap mitigation that works today, borrowed from the Flutter client above:
heartbeat keepalive, detect resume, offer to reattach — and make tmux/screen
reattach a first-class affordance rather than something the user types.

### 3. Importing `~/.ssh/config` is the highest-leverage onboarding feature

On desktop, every target user already has hosts configured. Typing them in
again is the reason an app gets abandoned in the first five minutes. Parsing
`~/.ssh/config` (and `known_hosts`) is comparatively cheap and should be in v1,
not "later".

## Credential storage — decided, then reversed

**Secrets never leave the device.** A password or a private key is written to
the OS keychain (`flutter_secure_storage`) and to nothing else. There is no
account, no backend, and no remote copy.

This reverses an earlier decision, and the reversal is the interesting part.

The first design synced secrets through Appwrite's **`encrypt` attribute**,
which encrypts at rest with the *server's* key. That tradeoff was raised and
accepted deliberately: Appwrite could decrypt them, so anyone with the
instance's `_APP_OPENSSL_KEY_V1` and database access — an operator, a backup, a
breach — could read stored SSH credentials. The alternative considered was a
client-sealed vault (XChaCha20-Poly1305 under an Argon2id-derived key, as
Termius does), declined for the recovery and first-device-login complexity it
adds.

What changed is the question. Both options answer "how do we hold someone's
credentials on a server safely?", and for an SSH client the better answer is
not to hold them at all. The data does not need continuous replication either:
a host list is near-static, so what people actually want is "get my servers
onto my phone" — a transfer, not a sync. Termius's cloud sync is the single
most cited reason people choose Blink or Prompt instead, which is a market
telling you something.

So: hosts, keys and tunnels move device-to-device by a **direct one-shot
transfer** the user initiates — a QR code on the desktop, scanned by the phone,
over the local network, with the channel sealed by a single-use secret carried
in the QR itself. The relay is open only while the sheet is open. Nothing is
stored anywhere but the two devices.

Three consequences, all binding:

1. **All secret access still goes through a single `SecretVault` interface.**
   That seam was the right call even though the reason for it changed; it is
   what made deleting the remote half a matter of removing one implementation
   rather than unpicking call sites.
2. **A device-local vault backed by the OS keychain**, gated by biometrics or
   device PIN (`local_auth`). Biometrics are never on by default and always
   have a PIN fallback — a user in gloves must not be locked out of their own
   servers.
3. **Backup is now the user's, so the app has to make it possible.** Losing a
   laptop with no cloud copy loses the keys, which the synced design covered by
   accident. An encrypted export — passphrase-derived key, AEAD, written
   wherever the user likes — is the replacement, and it keeps the property that
   no server ever holds anything readable.

## Sources

- [xterm2](https://github.com/SoFluffyOS/xterm2) ·
  [xterm.dart](https://github.com/TerminalStudio/xterm.dart) ·
  [dartssh2](https://github.com/TerminalStudio/dartssh2)
- [ConnectBot](https://github.com/connectbot/connectbot) ·
  [rudra-sah00/ssh-client](https://github.com/rudra-sah00/ssh-client)
- [Mosh](https://mosh.org/) · [Blink Shell](https://github.com/blinksh/blink)
- [ProxyJump / bastion hosts](https://www.redhat.com/en/blog/ssh-proxy-bastion-proxyjump)
- [Android foreground services](https://robertohuertas.com/2019/06/29/android_foreground_services/)
