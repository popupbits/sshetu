# SSHetu — open-source readiness

An audit of this repository against being made **public** on GitHub under the
MIT licence. Written on 2 October 2026, against `batch11-oss-readiness`
(84 commits on `main`, tip `c137d33`).

It covers four questions, in the order they matter: is there a secret in the
tree or in the history, is there personal data that becoming public would
publish, is every third-party licence honoured, and will a stranger who
arrives at this repository be able to build it, run the gates and send a pull
request without the maintainer's machine.

---

## Verdict

**Conditional go.** The code is clean, the licensing is clean, and the
contributor path now works without any of the maintainer's setup. Three
things need a decision from the owner before the switch is flipped — none of
them is in the code, and none can be fixed by an agent.

| | |
|---|---|
| Secrets in the working tree | **None.** No credential, token, keystore, `.env` or service-account file is tracked, and none ever was. |
| Secrets in 84 commits of history | **One throwaway SSH private key** (a test fixture), plus the owner's name, email and phone. Both are detailed below. |
| Third-party licences | **Clean.** 163 shipped packages, every one permissive; two MPL-2.0 files-level copyleft deps that are unmodified and therefore fine. |
| Build and test for an outsider | **Works.** CI needs no secrets; the `live` tests start their own `sshd`. |

---

## Blockers

| # | Blocker | Who must act | Status |
|---|---|---|---|
| **B1** | **A throwaway ed25519 private key is in the history** at commit `62c3f7d` (#3 of 84, 3 Sep) and again at `b0a9460` (#19), as the `opensshEd25519` fixture in `test/ssh/openssh_config_test.dart`. Removed from the tree in this branch, but history is history. GitHub's secret scanning runs over a repository when it becomes public and *will* raise an alert on it. | Owner — decide between rewrite and accept (below) | **Open** |
| **B2** | **The owner's real name, email (`***REMOVED***`) and phone (`+977…`) are in the history**, added by `c137d33` — which is the current tip of `main`. Removed from the tree in this branch. A phone number cannot be rotated. | Owner | **Open** |
| **B3** | **`CODE_OF_CONDUCT.md` has no reporting address.** It is written and complete apart from one line, which is deliberately left as `<CONDUCT CONTACT — set this before the repository is made public>`. A code of conduct with no working route to report is worse than not having one, and inventing an address that nobody reads is the same failure with better manners. | Owner | **Open** |
| **B4** | **`README.md` has no screenshots.** A terminal app with no picture is a hard sell, and the section is currently an honest placeholder. The screenshot workflows exist and have never been run. | Owner, or a later batch | Open — cosmetic, not a correctness blocker |

Nothing else found in this audit blocks publication.

---

## 1. Secret scan — the working tree and all 84 commits

### Method

`git log -p --all` was dumped to a 14.8 MB patch and walked by a purpose-built
Dart scanner (22 rules; the script is kept out of the repository because it is
a one-off). Every **added** line of every commit on every ref was tested
against: PEM private-key headers of all forms, PuTTY `.ppk` headers, the
`openssh-key-v1` magic, AWS access-key IDs and secret keys, GCP API keys and
service-account JSON, GitHub / Slack / Stripe / Google-OAuth tokens, JWTs,
bearer tokens, assigned `password|passphrase|api_key|client_secret|…` literals,
Gradle keystore properties, long base64 blobs (≥400 chars, the shape an
encoded keystore takes), `.env`-style release variables, and personal
phone/email/machine-path patterns.

Two allowlists, both deliberate:

- **Public keys are not secrets.** A line matching `ssh-ed25519 AAAA…`,
  `ssh-rsa AAAA…` or `ecdsa-sha2-nistp… AAAA…` is a *public* key and was
  skipped. This app is an SSH client; its tests and its UI are full of them,
  and treating them as findings would have buried the one real hit.
- **Source that merely names a marker** — a `RegExp(...)`, a `contains(...)`,
  a `hintText:` — is parser code, not key material.

In addition, every path ever added anywhere in history was listed and checked
against the sensitive-filename set (`.env*`, `key.properties`, `*.jks`,
`*.keystore`, `*.p12`, `*.pem`, `*.ppk`, `*.mobileprovision`, service-account
JSON, `*.p8`, `*.pfx`, `id_rsa`, `id_ed25519`). Binary additions were listed
separately, because `git log -p` does not show their contents.

### Result: 105 raw hits, 27 groups, one genuine finding

| What | Where | Still in HEAD | Verdict |
|---|---|---|---|
| **Complete, valid ed25519 private key** — the `opensshEd25519` fixture, with the comment `dlohani@DLs-M1.local` baked into the blob | `test/ssh/openssh_config_test.dart`, added `62c3f7d`, touched `b0a9460` | **No — removed in this branch** | **Genuine key material.** A throwaway generated on the maintainer's laptop, almost certainly never installed anywhere, but it is a real key and it is in the history. See B1. |
| Truncated OPENSSH key (one base64 line, not parseable) and a public key with `me@laptop` | `test/import/import_controller_test.dart`, `62c3f7d` | No — removed | Not a usable key, but the shape that trips a scanner. Replaced anyway. |
| `-----BEGIN RSA PRIVATE KEY-----` followed by `abcdef` / `MIIEowIBAAKCAQEA` | `test/ssh/openssh_config_test.dart` | Yes | **Not a secret.** Deliberate malformed input for the "is this encrypted?" parser. Nothing decodes. |
| `PuTTY-User-Key-File-3: ssh-ed25519\nEncryption: none` | `test/ssh/private_key_inspector_test.dart` | Yes | **Not a secret.** A header with no body, feeding the format detector. |
| PEM header strings | `lib/core/ssh/openssh_import.dart`, `private_key_inspector.dart`, `features/keys/widgets/paste_key_sheet.dart`, `test/ssh/fixtures/pasted_keys.dart` | Yes | **Not secrets.** Parser constants and a text-field hint. |
| `keyAlias = keystoreProperties["keyAlias"]`, `storePassword=` | `android/app/build.gradle.kts`, `android/key.properties.example` | Yes | **Not secrets.** The Gradle plumbing and an example file whose values are empty. |
| `passphrase: 'anything'` | `test/backup/backup_file_test.dart` | Yes | **Not a secret.** A literal called `anything`. |
| `/home/me/…`, `/Users/test//x`, `C:\Users\me\keys\work.ppk`, `/home/someone/Documents` | several tests | Yes | **Not personal.** Invented paths in test data. |
| Name, `***REMOVED***`, `+977…` | `ios/fastlane/metadata/review_information/`, `3e66a28`/`c137d33` | **No — removed in this branch** | **Genuine personal data.** See B2 and §2. |

**No** AWS, GCP, GitHub, Slack, Stripe or OAuth credential; **no** JWT; **no**
`.env` contents; **no** keystore bytes or base64 blob of one; **no**
service-account JSON; **no** Play or App Store Connect key, in the tree or in
any commit. Every fastlane file reads its credentials from the environment —
`ios/fastlane/Appfile`, `Matchfile` and `android/fastlane/Appfile` contain
`ENV[...]` lookups and the public bundle identifier, nothing more.

No sensitive filename was ever tracked. The only binaries ever committed are
app icons, launch images and the four `.ttf` font faces.

A local ref, `refs/karmashala/checkpoints/<session>`, holds two extra
checkpoint commits (`7ee925b`, `3e66a28`). It is not pushed and does not reach
GitHub; it is noted only because it appeared in the `--all` scan.

### B1 — the private key in history: the remedy, and the honest option

The key's **public** half, derived from the committed blob so it can be
searched for:

```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOy1j76uPwd+8rCu29HenRTqb+waM0gy6xSW00Fbu53k
SHA256:pdqwuyo6QDPGBpVxGYFjhZMtxy+qcMKhupxV/2A02JY
```

**Do this first, whatever else is decided.** Grep every machine the owner
administers for that fingerprint:

```sh
ssh-keygen -lf ~/.ssh/authorized_keys | grep pdqwuyo6
# on each server:
grep -F 'AAAAC3NzaC1lZDI1NTE5AAAAIOy1j76uPwd+8rCu29HenRTqb+waM0gy6xSW00Fbu53k' \
  /home/*/.ssh/authorized_keys /root/.ssh/authorized_keys 2>/dev/null
```

If it appears anywhere, delete that line — that is the only action that
actually matters, and it costs nothing. A private key in a public repository
is only a breach if the key authorises something.

Then choose:

- **Rewrite.** `git filter-repo --replace-text` (or BFG) over the two commits,
  then force-push. The key is at commit #3 of 84, so this rewrites 82 commit
  hashes. The repository is private and has one contributor, so nothing
  downstream breaks — this is as cheap as a rewrite ever gets. It is still
  irreversible, and GitHub keeps unreferenced objects reachable by SHA for a
  while; ask Support to run a garbage collection if the history must really
  be gone.
- **Accept.** Rotate (i.e. remove from `authorized_keys`) and publish anyway.
  The key becomes an ex-key the moment it authorises nothing. The visible cost
  is one GitHub secret-scanning alert to dismiss, and a reader who may draw
  conclusions about the project's hygiene from a key in commit #3.

**Recommendation:** check `authorized_keys` and rewrite. Both commits are old,
there is exactly one branch, and a project that ships an SSH client should not
have a private key in its history when the fix is an afternoon.

### B2 — the personal data in history

`c137d33` is the **tip of `main`**, so this one is unusually cheap: the four
files can be removed with an amend of a single commit and a force-push, with
no other hash disturbed. (`3e66a28` is the local checkpoint ref and never
leaves this machine.)

The thing that makes this different from the key: **an email address and a
phone number cannot be rotated.** Deleting them from the history removes them
from a place people would look; it does not un-publish them if anyone already
read them. Since the repository has been private throughout, nobody has. So
the realistic question is not "is this recoverable" — it is "do I mind this
being one `git log -p` away from any reader forever", and that is the owner's
call, not an auditor's.

Note that the owner's name and email are in the **author field of all 84
commits** regardless. That is ordinary and expected for an open-source
maintainer and is not treated here as a finding. The phone number is the part
that is unusual to publish.

---

## 2. Personal data — what was changed

Per the owner's decision, the App Store review contact details are out of the
repository:

- `first_name.txt`, `last_name.txt`, `email_address.txt`, `phone_number.txt`,
  `demo_user.txt`, `demo_password.txt` are **untracked and git-ignored**, with
  a `.example` beside each one. The real files stay on disk locally.
- `notes.txt` is **kept** — it is review guidance (what the app is, how to
  exercise it, the 4.2.7 answer, the permission reasons) — with its trailing
  `Contact: ***REMOVED***` line removed. Nothing else in it is personal.
- Documented in `RELEASE_READINESS.md` § *App Store review contact* and in
  `ios/fastlane/metadata/README.md`, including the trap: `deliver` runs with
  `submit_for_review: false`, so a **missing file does not fail the upload** —
  it uploads with the field unset and App Store Connect refuses the submission
  later. Writing those four files is a step of the release, not something
  fastlane will remind anyone about.

Also changed: the maintainer's username appeared as test data in five files
(`dlohani@laptop`, `"dlohani's MacBook"`, `dlohani-iPhone`, `dlohani@sshetu`).
Replaced with `tester`.

Checked and **clean**:

- `docs/`, `PROJECT.md`, `CONTRIBUTING.md`, `README.md`, `SECURITY.md` — no
  reference to the PopupBits hub, the credential store, an agent worktree, a
  WSL recipe, or any path under `C:\Users\…` or `/home/<user>/`.
- `RELEASE_READINESS.md` — the `Documents\sshetu.db` examples are the app's
  own former storage location, not anyone's filesystem.
- Every IP address in `lib/` and `test/` is RFC 1918 (`192.168.1.10`,
  `10.0.0.4`) or `example.com`. No real host, anywhere.
- `docs/prior-art.md` names *karmashala*, a sibling PopupBits project, as the
  source of the xterm patches that were evaluated. That is attribution, not a
  leak, and it is worth keeping.
- `.claude/skills/` (77 KB of prose) — no paths, no credentials, nothing
  internal. See §5.

---

## 3. Third-party licences

`THIRD_PARTY_NOTICES.md` is new and **generated**:

```sh
dart run tool/third_party_notices.dart           # rewrite
dart run tool/third_party_notices.dart --check   # exit 1 if stale
```

It reads `pubspec.lock` and `.dart_tool/package_config.json`, walks the
runtime dependency graph from the direct `dependencies:` (so dev-only
transitives such as the analyzer are excluded rather than padding the list),
reads each package's own `LICENSE` out of the pub cache, and names the licence
from its text — conservatively, reporting "see file" rather than guessing.

**163 shipped packages. A licence file was found for every one.**

| Licence | Count | Compatible with shipping inside an MIT app |
|---|---|---|
| BSD-3-Clause | majority | Yes |
| MIT | many | Yes |
| Apache-2.0 | several | Yes (notice requirement satisfied by the in-app licence page and this file) |
| BSD-2-Clause | `sqflite`, `sqflite_common_ffi` | Yes |
| MPL-2.0 | `dbus` 0.7.15, `nm` 0.5.0 | **Yes, with a condition** — see below |

**No GPL, no LGPL, no AGPL, no source-available or non-commercial licence.**

### The two MPL-2.0 packages

`dbus` and `nm` arrive on **Linux only**, under `connectivity_plus` and
`flutter_secure_storage_linux`. MPL-2.0 is *file-level* copyleft: it does not
reach the rest of the application, and §3.3 explicitly permits distributing a
larger work under other terms. The condition is that the source of the MPL
files stays available and that **modifications to those files are published**.
Neither is vendored and neither is modified, and both are on pub.dev, so the
condition is met as things stand. If either is ever forked into
`packages/`, that fork's source has to be published under MPL-2.0.

### Vendored and bundled

| What | Licence | Honoured? |
|---|---|---|
| `packages/xterm2/` — a fork of xterm2 5.3.0 | MIT, © 2020 xuty | **Yes.** `packages/xterm2/LICENSE` is the upstream text, unmodified, with the upstream copyright intact — which is the whole of what MIT asks. `packages/xterm2/VENDORED.md` names the upstream repository, the version, the exact commit and the date, lists all five diverging files with reasons, and documents the re-vendor procedure. `README.md` credits it, and it is now the first row of `THIRD_PARTY_NOTICES.md`. Flutter's licence collector picks up a path dependency's `LICENSE`, so it also reaches the in-app page. |
| JetBrains Mono, Fira Code, Source Code Pro, IBM Plex Mono | OFL-1.1 | **Yes.** Each face ships its `OFL.txt` beside the `.ttf`, and `RegisterFontLicenses` in `lib/core/theme/terminal_fonts.dart` — a bootstrap step, wired at `lib/core/bootstrap.dart:39` — registers that text with `LicenseRegistry`, so the licence travels with the *installed app*, which is what the OFL actually requires. Two carry Reserved Font Names ("Plex", "Source"); the faces are shipped unmodified, so the RFN clause is not engaged. A fork that *modifies* a face must rename it. |
| `assets/icon/sshetu.png` and the platform icon sets | PopupBits branding | **Deliberately not MIT.** `README.md` says so plainly: the code is MIT, the name and the look are not. That is a normal and defensible split, and it is stated where a forker will see it. |

### One gap worth naming

`--check` is **not wired into CI**. Adding it to `ci.yml` would make a
dependency bump that changes a licence a red build instead of a thing somebody
notices a year later. Not a blocker; a cheap improvement.

---

## 4. Public-repo hygiene

### Workflows — safe for a public repository

Every workflow was read with fork-PR attacks in mind.

| Workflow | Trigger | Secrets | Verdict |
|---|---|---|---|
| `ci.yml` | `push` (main/master), `pull_request`, `workflow_dispatch` | **none** | **Safe, and will pass for an outside contributor.** It runs `pub get`, format, analyze, `flutter test --exclude-tags live`, and a release desktop build on three runners. Nothing reads a secret, so a fork PR gets a genuine green or a genuine red. |
| `android-release.yml` | `workflow_dispatch` **only** | keystore, Play key | **Safe.** Manual dispatch cannot be triggered by a fork PR; it requires write access. No `push` trigger — "shipping is a decision", as its own header says. |
| `screenshots-android.yml` | `workflow_dispatch` only | none beyond `github.token` | **Safe.** `permissions: contents: write, pull-requests: write` is scoped to the workflow and unreachable from a fork. |
| `screenshots-ios.yml` | `workflow_dispatch` only | same | **Safe.** |

- **No `pull_request_target` anywhere.** That is the single most common way a
  public Flutter repository leaks its secrets, and it is absent.
- **No workflow runs untrusted code with secrets in scope.** The two that
  commit and open a PR are manual-only and use `github.token`, not a PAT.
- `.github/actions/open-screenshot-pr` pushes with `--force-with-lease` to a
  dedicated `screenshots/*` branch and opens a PR rather than pushing to
  `main`. Correct.
- `.github/actions/moksha-render` clones a **public** repository
  (`lohanidamodar/moksha`) at a ref, with no credential. Pinned to a branch
  (`main`) rather than a SHA — worth pinning to a SHA eventually, but it only
  runs on manual dispatch by someone with write access, so it is not an
  exposure.

**Not present, and worth adding later:** `dependabot.yml`, `CODEOWNERS`, and a
`--check` step for the notices file. None blocks publication.

### Documents

| File | State |
|---|---|
| `README.md` | **Updated.** Already written for strangers; added a screenshots section (an honest placeholder), a *The gates* section, a documentation index, a link to `CODE_OF_CONDUCT.md`, a link to `THIRD_PARTY_NOTICES.md`, and the four bundled fonts to the third-party list. The honest platform-status table — including *Linux: compiles green on CI, not yet run by a person* — was already there and is exactly right for a public repo. |
| `CONTRIBUTING.md` | **Updated.** Already covered the `material_ui` import rule and the three gates. Added: the two-ARB string rule and `test/l10n_parity_test.dart`; a *Tests* section; `git commit -- <path>` rather than `git add -A`; never commit a key, a real host or contact details, and reuse `test/ssh/fixtures/pasted_keys.dart`; all three test tags including `bench`; how to install `sshd` and run the `live` tests on a machine that is not the maintainer's; that CI needs no secrets; and a table of the optional tooling (`.mcp.json`, `.claude/`, `tool/`, fastlane) saying plainly that none of it is needed to build or test. |
| `CODE_OF_CONDUCT.md` | **New** — Contributor Covenant 2.1, verbatim, with the reporting address left as an explicit placeholder. See B3. |
| `.github/pull_request_template.md` | **New** — the three gates, "I ran the app and looked at what I changed", and a checklist carrying the `material_ui` rule, the two-ARB rule, and "no secrets, keys, personal addresses or real hostnames in the diff". |
| `.github/ISSUE_TEMPLATE/feature_request.md` | **New** — asks for the task rather than the feature, and names the two things the project deliberately will not do (a sync backend; editing `sshd_config`) so those requests get a pointer instead of a debate. |
| `.github/ISSUE_TEMPLATE/bug_report.md`, `config.yml` | Already good. `config.yml` routes vulnerabilities to a private advisory. |
| `SECURITY.md` | Already good — threat model, in scope, out of scope with reasons, private reporting route, and an honest "a timeframe we will tell you honestly rather than promise generically". |
| `LICENSE` | MIT, © 2026 PopupBits. Correct. |

---

## 5. What assumes the maintainer's environment

Everything below was checked for "would this confuse a contributor". The
answer is now no, with one judgement call.

| Thing | Finding |
|---|---|
| `.mcp.json` | Declares `dart mcp-server` (ships inside the Dart SDK, nothing to install) and `marionette_mcp` (needs `dart pub global activate marionette_mcp`). Only an agent reads it; it has no effect on a build. Now listed in `CONTRIBUTING.md` as optional, and `docs/agent-tooling.md` explains it. **Fine to ship.** |
| `.claude/skills/` | Five skills, 77 KB of prose, no paths and no credentials. `material-ui` is genuinely useful to any contributor hitting the frozen-Material type errors; `store-readiness`, `app-store-optimization` and `moksha` are release-side and of little use to an outsider, but they are harmless and they document how the listings are produced. `docs/agent-tooling.md` already says they are copies that do not self-update. **Judgement: ship it.** Removing it would cost the one skill that helps contributors and would hide how the store assets are made, to save 77 KB. |
| `dart_test.yaml` tags | `live`, `perf`, `bench` — all three now documented in `CONTRIBUTING.md` with how to run and how to exclude each. |
| The `live` tests | **Self-contained.** `test/ssh/live_connection_test.dart` starts its own `sshd` on a loopback port in a temp directory, with a throwaway host key and account, and skips itself when `/usr/sbin/sshd` is absent. Nothing of the maintainer's is read. `CONTRIBUTING.md` now gives the one-line install for Debian and Arch and says to use WSL on Windows. |
| `tool/` | `make_installer.ps1` (needs Inno Setup), `make_dmg.sh`, `generate_icons.py`, `screenshot_job.dart`, and the new `third_party_notices.dart`. None needed to build or test; now tabulated in `CONTRIBUTING.md`. `generate_icons.py` is the only Python in the repository and is a one-off. |
| Windows-only paths in tests | None. The `C:\Users\me\keys\work.ppk` in `test/import/putty/putty_fixture.dart` is *data* in a simulated registry export, parsed on every platform. CI runs the suite on Ubuntu, so this is proven rather than assumed. |
| `flutter pub get` dirties the tree on Windows | It was: pub rewrites the generated plugin registrants with LF, and `core.autocrlf` then showed seven files as modified in a checkout nobody had edited — a confusing first five minutes. **Fixed**: `.gitattributes` now pins those generated files to LF. |

---

## In-repo changes made in this branch

| Path | Change |
|---|---|
| `test/ssh/fixtures/pasted_keys.dart` | Added `generatedOpenSshPair({comment})`, which generates a real ed25519 key pair at test time and returns the private key with the full `.pub` line. |
| `test/ssh/openssh_config_test.dart` | The `opensshEd25519` literal — a complete private key with `dlohani@DLs-M1.local` in it — replaced by `generatedOpenSshPair().privateKey`. Same three assertions, same behaviour under test. |
| `test/import/import_controller_test.dart` | The literal private and public keys replaced by `generatedOpenSshPair(comment: 'me@laptop')`. |
| five test files | `dlohani` → `tester` in device names, key comments and the assertion that a sealed frame does not leak the device name. |
| `ios/fastlane/metadata/review_information/` | Six contact files untracked and ignored; a `.example` added for each; `Contact:` line stripped from `notes.txt`. |
| `.gitignore` | The six review-contact paths, with a comment saying who writes them and when. |
| `.gitattributes` | Generated plugin registrants pinned to LF. |
| `tool/third_party_notices.dart` | **New** — the notices generator, with `--check`. |
| `THIRD_PARTY_NOTICES.md` | **New** — generated. |
| `CODE_OF_CONDUCT.md` | **New** — Contributor Covenant 2.1. |
| `.github/pull_request_template.md`, `.github/ISSUE_TEMPLATE/feature_request.md` | **New**. |
| `README.md`, `CONTRIBUTING.md`, `RELEASE_READINESS.md`, `ios/fastlane/metadata/README.md` | Updated as described above. |

### Gates

All three run from this branch after the changes, read from a file with the
exit code captured:

```
dart format --output=none --set-exit-if-changed lib test   exit 0
flutter analyze                                            exit 0   No issues found!
flutter test --exclude-tags live                           exit 0   +2299 ~3  All tests passed!
```

No release or profile build was run, and the app was not launched — both were
out of scope for this audit.

---

## Before you flip the switch

1. **Grep every server's `authorized_keys`** for
   `SHA256:pdqwuyo6QDPGBpVxGYFjhZMtxy+qcMKhupxV/2A02JY` and delete any line
   that matches. Five minutes, and it is the only step that changes the real
   risk.
2. **Decide on the history** (B1, B2). Rewrite both, rewrite neither, or
   amend only the tip for the contact details — which is cheap, because
   `c137d33` is the tip and nothing downstream exists.
3. **Fill in the reporting address in `CODE_OF_CONDUCT.md`** (B3). The file is
   otherwise complete.
4. **Enable, on the repository:** secret scanning and push protection, private
   vulnerability reporting (`SECURITY.md` and the issue-template `config.yml`
   both already point at it), and branch protection on `main` requiring CI.
5. **Set Actions permissions for forks** to the default — require approval
   before running workflows on a first-time contributor's PR.
6. **Check that no organization secret is set to be visible to public
   repositories.** `android-release.yml`'s own header notes that organization
   secrets reach public repositories but not private ones on the free plan, so
   this repository's secrets are currently set per-repository. Going public
   changes which org secrets become reachable; look before flipping.
7. **Take screenshots** (B4), or leave the honest placeholder.
8. Optional, cheap: add `dart run tool/third_party_notices.dart --check` to
   `ci.yml`, add `dependabot.yml`, and pin `moksha-ref` to a commit SHA.
