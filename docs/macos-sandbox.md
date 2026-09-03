# macOS: the sandbox, the Keychain, and ~/.ssh

Debug and release do **not** have the same entitlements on macOS, and the
difference is load-bearing. This file exists so nobody discovers it the hard
way, at submission time.

## The situation

| | Debug | Release |
|---|---|---|
| App sandbox | **off** | on |
| Keychain (`flutter_secure_storage`) | works | needs `keychain-access-groups` **and a signing team** |
| Reading `~/.ssh` directly | works | **denied** — the folder picker is the only route |
| `network.client` | on | on |

## Why debug is unsandboxed

Not convenience — the sandboxed configuration does not build without a paid
developer account.

A sandboxed macOS app cannot touch the Keychain unless it is signed into a
keychain access group. Declaring `keychain-access-groups` requires a
development certificate and a `DEVELOPMENT_TEAM`, and with the ad-hoc signing
a fresh checkout uses, Xcode refuses to build at all:

```
error: "Runner" has entitlements that require signing with a development
certificate. Enable development signing in the Signing & Capabilities editor.
```

Leave the entitlement out and keep the sandbox, and the app builds but every
vault write fails with `errSecMissingEntitlement` (-34018) — which is exactly
what saving an imported private key does. That was hit for real during the
first test drive of the import feature.

So debug turns the sandbox off. The Keychain works, and `~/.ssh` is readable
directly, so import auto-detects rather than asking for a folder.

## What that costs, and what to do about it

**Two things work in debug that will not work in a release build until they
are tested in a release build.**

1. **Keychain access.** Release declares `keychain-access-groups`, which needs
   `DEVELOPMENT_TEAM` set in `macos/Runner/Configs/`. Until it is, a release
   build will not sign.

2. **Reading `~/.ssh`.** Under the sandbox this is denied outright, and
   `Directory.existsSync()` returns false — indistinguishable from the folder
   not being there. The app handles this: `OpenSshScanner.canScanHomeDirectly`
   is false on macOS, and the import screen offers a folder picker, which is
   what grants the sandbox permission to read it
   (`com.apple.security.files.user-selected.read-only`).

   **That path is not exercised by any debug run.** It has to be checked on a
   signed release build before shipping.

## Before shipping macOS

- [ ] Set `DEVELOPMENT_TEAM` and confirm a release build signs.
- [ ] On the release build: import → **Choose folder** → pick `~/.ssh`, and
      confirm hosts and keys are found.
- [ ] On the release build: import a key, quit, reopen, and confirm the key is
      still usable — that is the Keychain round trip the sandbox affects.
- [ ] Connect to a real host, to confirm `network.client` survived.

## Why not just sandbox debug too and skip the Keychain

Because the Keychain *is* the local vault. Falling back to anything else in
debug would mean testing a storage path that never ships — a worse lie than
the one documented here.
