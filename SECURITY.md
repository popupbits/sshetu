# Security policy

SSHetu holds the credentials to other people's servers. A bug here can cost
someone their infrastructure, so reports are taken seriously and the threat
model is written down rather than assumed.

## Reporting a vulnerability

**Please do not open a public issue.**

Use GitHub's private reporting: the **Security** tab → **Report a
vulnerability**. It is private to the maintainers, and it gives us a place to
talk before anything is public.

Useful things to include, in rough order of value: what an attacker gains, the
smallest reproduction you have, the version or commit, and the platform. A
proof of concept is welcome but not required — a clear explanation of the flaw
usually gets there faster than a script.

**What to expect.** This is a small project, so: an acknowledgement within a
few days, an assessment of whether we agree it is exploitable, and a fix in a
timeframe we will tell you honestly rather than promise generically. We will
credit you when it is fixed unless you would rather we didn't.

Please give us a reasonable chance to ship a fix before publishing. We will not
pursue anyone who reports in good faith and does not access other people's data
while finding it.

## Supported versions

The project is pre-release: **`main` is the supported version.** Once there are
tagged releases this section will say which of them still get fixes.

## In scope

- Anything that discloses a private key, a password or a passphrase — to
  another process, to disk outside the OS credential store, to a log, to a
  crash report, or over the network
- Weaknesses in the device-to-device transfer: the single-use secret, the
  sealed channel, or the window in which the listener accepts connections
- Weaknesses in the encrypted backup: the Argon2id derivation, the
  XSalsa20-Poly1305 body, or the readable envelope that a rewritten header is
  supposed to be refused by
- Host-key verification that can be bypassed, or a pinned key that stops being
  checked
- Command or shell injection into anything run on a remote host — notably the
  key-installation path, where the public key arrives on stdin and is matched
  with `grep -f` precisely so that neither it nor a label typed into it can
  become shell syntax
- Anything that makes the app trust a server it should not, or send a
  credential to a host that did not prove its identity

## Out of scope

These are known and deliberate, not oversights:

- **An attacker who already has your unlocked device or user session.**
  Credentials sit in the OS keychain (Keychain, Keystore, DPAPI, libsecret);
  anything with your logged-in session can ask the OS for them, as with every
  other client on that machine.
- **The app does not edit `sshd_config`.** Installing a key never disables
  password authentication server-side — that applies to every user and every
  client and needs a service reload, and a mistake locks everyone out of a
  machine that may be in another country. It changes only what the app uses
  and stores.
- **Trust on first use.** An unknown host key is shown with its fingerprint for
  you to accept, the way `ssh` does. Accepting one without checking it is a
  decision the UI asks you to make, not a bug.
- **Unsigned binaries.** Desktop builds are unsigned, so SmartScreen and
  Gatekeeper warn on first run. That needs a paid certificate; it is a gap we
  name rather than hide.
- Vulnerabilities in a dependency with no path to exploiting them through this
  app. Report those upstream; tell us too if we should pin or patch.
- Anything requiring a physical attack on a device that is already compromised,
  or that assumes the user pastes an attacker's key on purpose.

## Design notes a reporter may find useful

- There is **no backend**. No account, no sync server, nothing to breach
  centrally. Hosts, keys and tunnels live in a local SQLite database;
  credentials live only in the OS credential store, reached through a single
  `SecretVault` interface that nothing else bypasses.
- The device-to-device transfer's listener is open **only while its screen is**,
  and the channel is sealed by a single-use secret that travels in the QR code
  rather than over the network.
- The on-device diagnostics log is deduplicated, capped, and never leaves the
  device unless the user deliberately shares it.

`docs/prior-art.md` records the decisions that were made and, in one case,
reversed — including why credentials stopped being synced.
