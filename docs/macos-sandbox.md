# macOS: the Keychain, the sandbox, and ~/.ssh

Three macOS-specific things bit this app during its first test drive. All are
fixed; this records what was actually wrong, because two of them presented as
something else entirely.

## 1. The Keychain — "Unexpected security result code"

**Symptom:** importing keys failed with a `SecretVaultException`. Every vault
write failed, sandboxed or not, signed or not.

**Cause:** macOS has *two* keychains. `flutter_secure_storage`'s `MacOsOptions`
defaults `usesDataProtectionKeychain` to **true**, selecting the
data-protection keychain, which behaves like iOS: it requires the app to be
signed into a keychain access group. That needs `keychain-access-groups`, which
needs a `DEVELOPMENT_TEAM`. Without one, `SecItemAdd` fails and the plugin
reports the unhelpful `PlatformException: Unexpected security result code`.

**Fix:** `KeychainSecretVault` sets `usesDataProtectionKeychain: false`, using
the legacy file-based login keychain. Verified working both sandboxed and
unsandboxed, with ad-hoc signing and no team.

**If this app is ever submitted to the Mac App Store with a real team:** the
data-protection keychain is the better home for secrets, but flipping the flag
moves where items live. Existing users would need a migration, not a flag flip.

**The wrong turn worth remembering:** the first fix assumed the sandbox was
blocking the Keychain and disabled the sandbox in debug. It did not help,
because the sandbox was never the problem — and it would have left debug and
release behaving differently for no gain. Get the error code before changing
the configuration; `SecretVaultException` carries one now, precisely so the
next person does not have to guess.

## 2. Outgoing connections

Flutter's macOS template does not include `com.apple.security.network.client`.
Without it the sandbox denies `connect()` and **every host looks unreachable** —
an SSH client that cannot open a single socket. Both entitlement files declare
it now, and they are otherwise identical apart from `allow-jit` in debug.

Keeping the two files in agreement matters more than it looks: a release that
omits `network.client` ships an app that cannot connect, and nothing in a debug
run would reveal it.

## 3. Reading ~/.ssh

Under the sandbox `~/.ssh` is invisible. `Directory.existsSync()` returns
**false** — verified on a real build — which is indistinguishable from the
folder not existing. There is no entitlement that fixes this, and there should
not be: that folder holds every private key the user owns.

The import screen therefore offers a folder picker, and picking the folder is
what grants the sandbox permission to read it
(`com.apple.security.files.user-selected.read-only`). The panel opens *inside*
`~/.ssh` rather than at the home directory, because `.ssh` is a dotfile and
would otherwise be hidden behind a keyboard shortcut most people do not know.

`OpenSshScanner.canScanHomeDirectly` is false on macOS and true on Linux and
Windows, where auto-detection works with no picker.

**The sandbox is on in debug as well as release**, so this path is exercised
every time anyone imports on a Mac, rather than being a release-only surprise.

## Before shipping macOS

- [ ] Connect to a real host — confirms `network.client`.
- [ ] Import → **Choose folder** → `~/.ssh`, confirm hosts and keys are found.
- [ ] Import a key, quit, reopen, connect with it — the Keychain round trip.
- [ ] If a signing team is added, re-run all three: entitlements resolve
      differently once `$(AppIdentifierPrefix)` is real.
