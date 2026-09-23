# SSHetu — store readiness

**Targets:** Google Play (Android) and the App Store (iOS). macOS, Windows and
Linux ship outside the stores — dmg, Inno Setup installer, CI bundle — and are
covered here only where a store answer depends on them.

**Audited:** 22 September 2026, against the live pages, not from memory:

| Verified | Result |
| --- | --- |
| [Play target API level](https://developer.android.com/google/play/requirements/target-sdk) | New apps and updates must target **API 36** since **31 August 2026** (extension to 1 November 2026 on request) |
| [Play Data safety](https://support.google.com/googleplay/android-developer/answer/10787469) | Every app must complete the form, *including* one that collects nothing, and it needs a privacy-policy URL to submit |
| [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/) | 2.1(a) completeness, 4.2.7 remote desktop clients, 5.1.1(i) privacy policy, 5.1.1(ii) purpose strings |

**Verdict: not submittable today.** The build itself is in good shape — the
target API level is current, the permissions are all justified, the foreground
service is typed and documented. What is missing is everything outside the
binary: there is no privacy policy anywhere, no support URL, no store artwork,
no screenshots, and the listing copy still says TODO. Eight blockers below;
six of them are the owner's, in a console or on a web host, and cannot be
fixed in this repository.

---

## Blockers

Ordered by what stops you first.

| # | Store | Finding | Reference | Who |
| --- | --- | --- | --- | --- |
| B1 | Both | **No privacy policy exists.** Not in the repo, not on a host, not in the listing — `ios/fastlane/metadata/en-US/privacy_url.txt` is empty and Play's field is unset. Play will not accept the Data safety form without one; Apple rejects without one in metadata *and* reachable in-app. | Play Data safety; Apple 5.1.1(i) | **Owner** to host; drafted here |
| B2 | App Store | **Support URL is empty.** `ios/fastlane/metadata/en-US/support_url.txt` ships blank on purpose (`metadata/README.md` says so). Apple requires a working `https://` page and rejects a `mailto:`. | Apple 2.1(a) | **Owner** |
| B3 | Both | **Listing copy is placeholder.** `android/…/full_description.txt` and `ios/…/description.txt` both literally contain "TODO: Write the full … before the first release." `deliver` and `supply` upload them verbatim. | Apple 2.1(a); Play listing policy | **Owner** (copy); `app-store-optimization` skill |
| B4 | Both | **No store artwork or screenshots at all.** No 512×512 icon, no 1024×500 feature graphic, no phone screenshots under `android/fastlane/metadata/`; `ios/fastlane/screenshots/` does not exist. Play cannot publish without an icon, a feature graphic and two phone shots. The iOS target is `TARGETED_DEVICE_FAMILY = "1,2"`, so Apple needs **iPhone 6.9" and iPad 13"** sets. | Play listing requirements; Apple screenshot specs | **Us** — run the two screenshot workflows (PROJECT.md §10) |
| B5 | App Store | **Export compliance is unanswered, and the honest answer is not the house default.** `ITSAppUsesNonExemptEncryption` was absent. It is now `true` (see below) — which is correct for an SSH client and which means the build lands in **Missing Compliance** until documentation is on file. | US EAR; App Store Connect export compliance | **Owner** (BIS filing) |
| B6 | Play | **`FOREGROUND_SERVICE_SPECIAL_USE` is undeclared in the Play Console,** and the declaration needs a screen-recorded demo video. Without it the release is rejected at review. Text is written (PROJECT.md §12c, repeated below); the video is not recorded. | Play foreground service policy | **Owner** |
| B7 | Play | **Data safety form and IARC content rating are not submitted.** An unrated app cannot be published, and the Data safety form is mandatory even for an app that collects nothing. | Play policy | **Owner** — answers below |
| B8 | Play | **Release signing is unproven.** `android/key.properties` is absent (correctly — it is gitignored), and `android/app/build.gradle.kts` falls back to the **debug** signing config when it is missing. That builds fine and is rejected at upload with a confusing error. The CI workflow injects a keystore from secrets; nobody has yet uploaded an AAB from it. | Play upload | **Owner** — confirm secrets, then upload to the internal track first |

### Fixed in this branch

These were blockers or near-blockers and are now closed in the repo. None of
them has been proven on a device — see *What is unverified* at the end.

| # | Store | Was | Now |
| --- | --- | --- | --- |
| F1 | App Store | **No `NSLocalNetworkUsageDescription`.** Since iOS 14 the system refuses local-network traffic without it — which here means connecting to a server at `192.168.x.x` and the whole *Send to a device* transfer, both silently failing as "unreachable". This is one of the most common rejections for this class of app. | Added to `ios/Runner/Info.plist`, with a specific purpose string. Also added to `macos/Runner/Info.plist`: macOS 15 brought the same prompt to the Mac. **No `NSBonjourServices`** — nothing in this app browses or advertises over mDNS; the receiver reads the sender's address out of the QR code. Declaring Bonjour it does not use would only invite a question. |
| F2 | App Store | **No `ios/Runner/PrivacyInfo.xcprivacy`.** Required since May 2024, and it fails at *upload*, before a human sees the app. | Added, declaring no tracking, no collected data, and the two required-reason APIs the app itself touches (file timestamps `C617.1`, UserDefaults `CA92.1`). Registered in the Runner target's Resources build phase — a manifest that is not copied into the bundle is indistinguishable from not having one. |
| F3 | Both | **`android:allowBackup` was the default, `true`.** Android was free to copy the host database, the settings and the encrypted credential store to Google Drive, and to hand them to a new phone over device-to-device transfer. For an app holding the keys to someone's infrastructure that is wrong on privacy grounds — and broken on top: the AndroidKeyStore master key never leaves the old device, so a restored host list has credentials nothing can decrypt. | `android:allowBackup="false"` plus `res/xml/data_extraction_rules.xml` excluding every domain from **both** `<cloud-backup>` and `<device-transfer>` — `allowBackup` alone does not cover D2D on Android 12+. |
| F4 | App Store | Export compliance unanswered, so App Store Connect asked on every upload. | `ITSAppUsesNonExemptEncryption` set to `true`, with the reasoning in the plist. |
| F5 | — | None of the above was pinned by a test. | `test/ios_plist_test.dart` (new) and the `backup` group in `test/android_manifest_test.dart`. |

---

## Should fix

| # | Store | Finding | Who |
| --- | --- | --- | --- |
| S1 | Both | **The in-app privacy policy link does not exist.** `aboutPrivacyPolicy` and `aboutPrivacyPolicySubtitle` are already in *both* ARB files, but `lib/features/settings/about_screen.dart` shows only Licences. Apple 5.1.1(i) wants the policy reachable inside the app. Wire the tile as soon as B1 gives it a URL — the strings are waiting, so this is one `ListTile` and a `url_launcher` call. Doing it before the URL exists would ship a dead link, which is Guideline 2.1. | Us, after B1 |
| S2 | Both | **The UI font is downloaded at runtime.** `google_fonts` serves Inter, and Inter is not in `pubspec.yaml`'s `fonts:` — only the four terminal faces are. So a fresh install fetches `fonts.gstatic.com` on first launch: an offline first run draws the UI in a fallback face, and an app that says "nothing leaves the device" makes a request to Google before it has shown a screen. Bundling Inter the way the terminal faces are bundled removes both, and removes a question from the Data safety form. | Us — a separate change, not part of this audit |
| S3 | App Store | **No `ios-release.yml` workflow and no `ios/ExportOptions.plist`.** The shared pipeline (`popupbits-release-pipeline`) expects both; the fastlane lanes under `ios/` are correct and complete, so a release is possible from a Mac by hand, but not from CI. | Us / owner |
| S4 | App Store | **`ios/fastlane/metadata/` is missing `primary_category.txt`, `secondary_category.txt` and `review_information/`,** which the shared pipeline lists. Without `review_information/` the App Review notes (below) have nowhere to live in the repo and have to be typed into ASC each time. Suggested category: **Developer Tools**, secondary **Utilities**. | Us |
| S5 | App Store | `subtitle.txt`, `keywords.txt` and `promotional_text.txt` are empty. Not rejections, but Apple indexes only name + subtitle + keywords, so an empty subtitle and empty keywords make the app effectively unfindable. | Owner / `app-store-optimization` |
| S6 | Play | `android/fastlane/metadata/android/` has only `en-US`. Play accepts Nepali (`ne-NP`) and the app is localised into it; the App Store's fixed language list has no `ne`, which is why that asymmetry exists. Adding `ne-NP` is free reach. | Owner |
| S7 | Both | The app has no "what's new" for a first release worth reading, and `changelogs/default.txt` is still the template's warning text. **Owned by a parallel change — not touched here.** | Other agent |
| S8 | Play | After the first release that ships the keep-alive service, watch **Android vitals → excessive partial wake locks**. `specialUse` has no six-hour cap, but the wake lock is still measured, and a bad score is a store-listing penalty. PROJECT.md §12c says so too. | Owner, post-release |

---

## What a reviewer will look at twice

An SSH client does things that look alarming out of context. None of them is a
policy problem; all of them are worth saying first, in the review notes, rather
than being asked about.

| Feature | Disclose where | What to say |
| --- | --- | --- |
| **Remote shell** | Apple review notes; Play "App access" is not needed (no login) | The app is a protocol client. It connects to servers the user configures, with the user's own credentials, and runs what the user types. It does not download or execute code on the device — Apple 2.5.2 is about the app's own binary, and nothing here changes the app's features at runtime. |
| **Guideline 4.2.7 (Remote Desktop Clients)** | Apple review notes | 4.2.7 opens with *"If your remote desktop app acts as a mirror of specific software or services rather than a generic mirror of the host device"*. SSHetu mirrors nothing and streams no screen: it is a terminal emulator speaking SSH to a server the user owns, so 4.2.7(a)'s LAN-only restriction does not apply. Say this in the notes; a reviewer reaching for 4.2.7 is the single likeliest iOS rejection, and it is answerable in two sentences. |
| **SFTP file transfer** | Nothing to declare | Files move between the device's own sandbox and the user's server. No `MANAGE_EXTERNAL_STORAGE`, no media permissions, no shared-storage access — imports and exports go through the system file picker. |
| **The MCP server** | Nothing on either store | Desktop only, and gated by a *platform capability*, not by layout: `mcpSupportedProvider` is false on Android and iOS, so the switch does not exist in a mobile build and the server can never start there. The Dart code is compiled into the mobile binary and unreachable. Worth one line in the notes so nobody finds `HttpServer` in a strings dump and wonders. |
| **Session logging** | The app already says it, in `sessionLogPrivacyNote` | Off by default, writes to a folder the user picks, never leaves the device. Nothing to declare. |
| **The tmux installer running `sudo`** | Apple review notes, briefly | It runs on the **remote server**, over the connection the user already opened, using the user's own account and the server's own `sudo` policy — `sudo -n` first, and only ever a shell the user is watching. Nothing is elevated on the phone. |
| **Agent forwarding** | Nothing to declare | Off by default, per host, and only to the host the user turned it on for (`SshConnection` forwards to the target hop only). |
| **Keeping connections alive** | **Play: required declaration** — B6 | See the special-use text below. |

### App Review notes — draft

> SSHetu is an SSH client. It connects to servers that the person using it
> owns or administers, with credentials they enter themselves, and shows a
> terminal. There is no account, no backend and no analytics: hosts, keys and
> known-host fingerprints are stored in this device's database and the iOS
> Keychain, and nothing is sent anywhere except to the server being connected
> to.
>
> Reviewing it needs a server to connect to. Any host that accepts SSH will
> do; if it is easier, we can provide a temporary throwaway account — please
> ask and we will attach credentials.
>
> Two things worth mentioning up front:
>
> • Guideline 4.2.7 applies to remote desktop apps that mirror specific
> software or a host's screen. SSHetu mirrors nothing and streams no display;
> it is a terminal emulator speaking the SSH protocol, like an email client
> speaks IMAP.
>
> • "Send to a device" copies the user's own configuration between their own
> two devices over the local network, sealed with a single-use secret carried
> in a QR code. This is why the app asks for local network access, and it is
> the only feature that listens on a socket. It is also why the app asks for
> the camera — to scan that QR code, and nothing else.
>
> The app runs a local integration server for AI assistants on desktop only.
> That feature does not exist in the iOS build.

---

## Play Data safety — the exact answers

Enter these in **Play Console → App content → Data safety**. Every one of them
is checkable against the repository, which is the point: Google holds the
developer responsible for the answers staying true after an update.

**Does your app collect or share any of the required user data types?** → **No.**

That is the whole form. Play's own definition excludes *"data only processed
locally on the user's device and not sent off device"*, which is every row of
SSHetu's database. Everything below is the justification, not extra answers:

| What Play asks about | SSHetu | Why |
| --- | --- | --- |
| Personal info, financial info, health, messages, photos, contacts, calendar | Not collected | The app never reads any of it. |
| Files and docs | Not collected | It reads only a file the user picks in the system picker (an OpenSSH config, a key) and writes only where they choose (a backup, a session log). Nothing is transmitted. |
| App activity, app info and performance, crash logs, diagnostics | Not collected | Errors go to a 50-record log in this device's preferences, shown at Settings → Diagnostics. `main.dart` says in as many words that there is no sink and adding one would be a privacy decision. No crash reporter, no analytics SDK. |
| Device or other IDs | Not collected | Nothing reads an advertising ID or a device identifier. |
| Location | Not collected | No location permission, no location API. |
| Data shared with third parties | None | There is no third party. |

**Security practices** (shown only once data types are declared — noted here so
the answers are on record if a future version collects anything):

- *Data is encrypted in transit* — yes, everything the app sends is inside SSH
  or, for the device transfer, XSalsa20-Poly1305 over a Curve25519-derived key.
- *Users can request data deletion* — there is no account and no server, so
  there is nothing to request. Uninstalling removes the database, the settings
  and the credential-store entries.

**Two things to be honest about, neither of which changes the "No":**

1. **The font fetch.** `google_fonts` downloads Inter from `fonts.gstatic.com`
   on first launch (S2). That request carries the device's IP address, like any
   web request; Play does not treat standard network transmission as collected
   data, and nothing about the user or their servers is in it. Bundling Inter
   removes the question entirely — do it.
2. **Play Core.** `in_app_update` and `in_app_review` talk to the Google Play
   services on the device. They are Google's services, not the developer's,
   and they are outside the Data safety declaration.

**Also on the App content page:** Ads → *no ads*. Target audience → adults
only (18+), which keeps Families policy out of it — this is a developer tool.
Government apps → no. Financial features → none. Health → none. News → no.

### IARC content rating questionnaire

Answer everything **No**, with two worth thinking about before you click:

- *Does the app let users interact with or exchange content with other users?*
  — **No.** A user connects to their own server. There is no user-to-user
  channel, no chat, no shared content, no profile.
- *Does the app provide unrestricted access to the internet, like a browser?*
  — **No.** It speaks SSH to hosts the user configures. It renders no web
  content and has no address bar. (If Play's wording in the console differs
  from this, answer what the console asks and keep a note of it here.)

Expected outcome: *Everyone / PEGI 3 / ESRB Everyone*. Record the certificate
IDs the IARC returns.

---

## App Store — App Privacy, and the rest of App Store Connect

**App Privacy → "Do you or your third-party partners collect data from this
app?" → No.** The nutrition label then reads **Data Not Collected**, which
matches `ios/Runner/PrivacyInfo.xcprivacy` exactly, and it must keep matching:
a label that drifts from the manifest is a post-review removal, not a
rejection.

The same two honest notes as Play apply — the font fetch is a CDN request, not
collection, and there is no Play Core on iOS.

| Field | Answer |
| --- | --- |
| Age rating | 4+. No objectionable content, no user-generated content, no web browser. |
| Category | Primary **Developer Tools**, secondary **Utilities** |
| Demo account | None needed — there is no login. Offer a throwaway SSH host in the review notes instead (see the draft above); a reviewer with nothing to connect to may call it 2.1. |
| Content rights | The app contains no third-party content. |
| Price | Free (confirm) |

### Export compliance — the answer, and why it is not `false`

The shared PopupBits pipeline says to set `ITSAppUsesNonExemptEncryption` to
`false`. **That is the wrong answer for this app**, and it has been set to
`true` in `ios/Runner/Info.plist`.

`false` means "my app's encryption is exempt" — which is true for an app whose
only crypto is HTTPS through the operating system. SSHetu is not that app. It
implements the SSH transport itself, in Dart, and carries published ciphers
(AES-GCM, ChaCha20-Poly1305), key exchange (Curve25519, ECDH) and signature
algorithms (Ed25519, ECDSA, RSA) through `dartssh2`, `pinenacl`, `pointycastle`
and `cryptography`. None of App Store Connect's exemptions fits: it is not
limited to authentication or digital signature, not limited to the operating
system's own encryption, not HTTPS-only. Answering `false` would be a false
statement on a United States export declaration.

What App Store Connect then asks, and the answers:

1. *Does your app use encryption?* → **Yes**.
2. *Does it qualify for any of the exemptions?* → **No**.
3. *Does your app implement any proprietary or non-standard encryption
   algorithms?* → **No** — every algorithm above is a published standard.
4. *Is your app available on the French App Store?* → answer honestly; France
   has its own declaration.

Because of (2) and (3) the app is standard mass-market encryption
(ECCN **5D992.c**), and App Store Connect will want export documentation
before the build can be distributed. Until it is on file the build sits in
**"Missing Compliance"** in TestFlight and cannot be submitted.

> **Owner action, and the one item here that is not a software task.** The
> route for standard mass-market crypto is self-classification with the US
> Bureau of Industry and Security — an encryption registration through SNAP-R
> and the annual self-classification report — after which App Store Connect
> accepts the documentation and issues a code you can put in the plist as
> `ITSEncryptionExportComplianceCode` so it never asks again. **Get this
> confirmed by someone who does export compliance for a living before filing.**
> This document is an engineering audit; the classification is a legal one.

---

## The Play special-use declaration

**Play Console → App content → Foreground service permissions.** Select
`FOREGROUND_SERVICE_SPECIAL_USE`, choose to enter the use case manually, and
paste this. It is the text held in PROJECT.md §12c — if the two ever disagree,
§12c is the source.

> **Description.** SSHetu is an SSH client. When the user opens an interactive
> terminal session or starts an SSH port forward to a server, the app starts a
> special-use foreground service that keeps those user-initiated connections
> open while the user switches to another app — for example to copy a command
> from a browser or answer a message mid-session. The service does no work of
> its own; it keeps the process alive so the open SSH connections are not
> dropped. It shows a persistent notification listing what is connected, with
> a "Disconnect all" action, runs only while at least one user-opened
> connection is active, and stops as soon as the last one closes. It can be
> turned off in Settings.
>
> **User impact if deferred or interrupted.** The user's live SSH sessions and
> port forwards are disconnected. Any command running interactively in the
> session is lost or killed on the server, unsent input is lost, and the user
> has to reconnect and re-authenticate. It cannot be deferred: the connection
> exists only while the user is using it, and no other API keeps an
> interactive TCP session open in the background.

The form also asks for **a video**. Record, in one take: connect to a server,
switch to another app, show the notification, come back to the still-live
session, then tap **Disconnect all**. Upload it unlisted to YouTube and paste
the link.

The manifest half is already done and pinned by
`test/android_manifest_test.dart`: `foregroundServiceType="specialUse"`, the
`android.app.PROPERTY_SPECIAL_USE_FGS_SUBTYPE` property, and
`FOREGROUND_SERVICE_TYPE_SPECIAL_USE` in `KeepAliveService.kt`.

---

## Permissions, and what justifies each one

Audited against the features that use them. Nothing is declared that nothing
uses, and nothing arrives unannounced from a plugin.

| Permission | Justified by | Note |
| --- | --- | --- |
| `INTERNET` | Every connection the app makes | Declared in the **main** manifest, not just debug/profile — see the comment there; it cost an emulator install to learn. |
| `CAMERA` + `uses-feature camera required="false"` | The transfer QR scanner (`mobile_scanner`) | Asked at the moment the scanner opens. The app is fully usable without it: the code can be pasted as text. |
| `USE_BIOMETRIC` | The optional credential lock (`local_auth`) | Off by default. `BiometricPrompt` also offers the device PIN, so no sensor can lock anyone out. `minSdk` is 24 (Flutter's default); `local_auth` needs 23. Fine. |
| `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_SPECIAL_USE` | `KeepAliveService` | B6. |
| `WAKE_LOCK` | The same service's `PARTIAL_WAKE_LOCK` | Held only while a connection is open; `wakelock_plus` separately holds the *screen* awake only while a terminal tab is attached. |
| `POST_NOTIFICATIONS` | The keep-alive notification | Requested at the first connection, never at launch. The service runs whether or not it is granted. |
| `ACCESS_NETWORK_STATE` | Merged in by `connectivity_plus` | Not written in this app's manifest; it arrives from the plugin's. Used to tell a reconnecting session that the network is back (`features/sessions/reconnect_triggers.dart`) instead of making it wait out its countdown. It is a normal permission, invisible to the user, and does not need a declaration — but it *will* appear in the merged manifest, so do not be surprised by it in the Play Console's permission list. |
| `<queries>` for `ACTION_PROCESS_TEXT` | Flutter's own text-selection toolbar | Template default. Not `QUERY_ALL_PACKAGES`, which would need a permitted-use declaration. |

**Not present, and correctly so:** no location, no contacts, no media, no
`QUERY_ALL_PACKAGES`, no `SCHEDULE_EXACT_ALARM`, no `MANAGE_EXTERNAL_STORAGE`,
no SMS or call log.

**Network security config:** none, and none is needed. There is no cleartext
`http://` anywhere in `lib/`; the platform's cleartext policy governs the HTTP
stack, and this app's traffic is raw SSH sockets plus a loopback-only desktop
server. Adding a config file would be noise.

---

## Build facts, checked

| Thing | Value | Verdict |
| --- | --- | --- |
| `applicationId` / bundle id | `com.popupbits.sshetu` on Android, iOS and macOS | Consistent, and pinned by `test/native_identity_test.dart` |
| Debug identity | `com.popupbits.sshetu.debug`, `.debug` suffix on the debug build type only | Never reaches a store build |
| `targetSdk` | `flutter.targetSdkVersion` = **36** on Flutter 3.47.2 | Meets Play's 31 August 2026 requirement |
| `compileSdk` | 37, pinned above Flutter's default for `flutter_secure_storage` | Fine — compile surface only |
| `minSdk` | `flutter.minSdkVersion` = 24 | Fine for `local_auth` and `BiometricPrompt` |
| `versionCode` / `versionName` | `flutter.versionCode` / `flutter.versionName` from `pubspec.yaml` (`1.0.0+1`) | The bump is a parallel change; not touched here. **A version code may never be reused, including by a build uploaded outside git.** |
| 64-bit / ABIs | Flutter's App Bundle carries `arm64-v8a`, `armeabi-v7a` and `x86_64` | Play's 64-bit requirement is met by the bundle |
| Upload format | `play_publish` builds an **AAB** | Correct; APKs are not accepted for new apps |
| Adaptive icon | `mipmap-anydpi-v26/ic_launcher.xml` with background, foreground **and monochrome** | Complete, including the themed-icon layer |
| Splash | `drawable/launch_background.xml` with `values-night` beside it | Plain white; not a rejection, worth a look |
| iOS deployment target | 15.0; macOS 12.0; device family `1,2` (iPhone **and** iPad) | iPad screenshots are therefore required — B4 |
| macOS sandbox | `app-sandbox`, `network.client`, `network.server`, `device.camera`, `files.user-selected.read-write`; `allow-jit` in debug only | Matches the features shipped; `docs/macos-sandbox.md` explains each. Not a Mac App Store submission — the dmg is signed ad-hoc or with Developer ID (PROJECT.md §12a). |
| Account deletion | Not applicable | No account, no sign-in, nothing to delete. Apple 5.1.1(v) and Play's deletion requirement both apply only to apps with account creation. |
| Third-party sign-in | None | Apple 4.8 does not apply. |
| In-app purchase | None | Apple 3.1.1 does not apply. |
| Placeholder scan | `TODO` in two listing files (B3); no `example.com`, no `lorem ipsum`, no `http://` in `lib/` | |

---

## First release, step by step

Do these in order. The first four are not in this repository.

**Before anything is built**

1. **Write the privacy policy and host it** (B1). `docs/privacy-policy.md` is a
   complete draft — read it, fix the contact line, put it on a public
   `https://` page that is not a PDF and not geofenced. Put the URL in
   `ios/fastlane/metadata/en-US/privacy_url.txt`, in the Play Console listing,
   and in App Store Connect.
2. **Put up a support page and fill `support_url.txt`** (B2). A page, not a
   `mailto:`.
3. **Write the listing copy** (B3) — `full_description.txt`, `description.txt`,
   `subtitle.txt`, `keywords.txt`. The `app-store-optimization` skill is for
   exactly this.
4. **Generate the screenshots** (B4): *Actions → Screenshots (Android)* and
   *Screenshots (iOS)*. Both open a pull request; review the diff. Then produce
   the 512×512 icon and the 1024×500 feature graphic — the `moksha` skill
   renders and validates both against each store's upload rules.

**Console setup**

5. Create the app in the **Play Console** (it stays a Draft until the first
   release) and in **App Store Connect**.
6. Play → App content: **Data safety** (answers above), **content rating**
   (IARC), **target audience** 18+, **ads** none, **privacy policy URL**, and
   the **foreground service declaration with its video** (B6).
7. App Store Connect: **App Privacy → Data Not Collected**, **age rating 4+**,
   **category Developer Tools**, privacy and support URLs, and paste the
   **App Review notes** from above.
8. Start the **export-compliance filing** (B5). It gates the iOS submission and
   it is the item with the longest lead time — begin it first, not last.

**Build and upload**

9. Confirm the Android signing secrets are set on the repository (B8):
   `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`,
   `ANDROID_KEY_PASSWORD`, `PLAY_STORE_JSON_KEY_DATA`, `APP_IDENTIFIER`. Never
   read or copy the values — confirm the names exist in the Settings page.
10. **Actions → Android Release → `internal`.** Internal first, always: it is
    the cheapest place to discover that a build was debug-signed or that a
    version code was already used. Install from the internal track on a real
    phone and connect to a real server.
11. iOS: from a Mac, `cd ios && bundle exec fastlane beta` for TestFlight (S3
    is why this is not a CI button yet). Answer the compliance prompt using the
    filing from step 8.
12. Promote to `beta`, then `release` on Play; submit for review on the App
    Store.

**Desktop, on the same version**

13. **Watch the one-time database move** (PROJECT.md §12d). This is the first
    release build that will run it on a real machine, and it is the one thing
    in this release that can lose a user's data. On Windows and Linux, on a
    machine that has an old install with `Documents\sshetu.db`:
    - Take a copy of `Documents\sshetu.db` somewhere safe first.
    - Install the release build and launch it once.
    - Confirm `%APPDATA%\PopupBits\SSHetu\sshetu.db` (or
      `$XDG_DATA_HOME/com.popupbits.sshetu/sshetu.db`) now exists, that the
      hosts, identities, tunnels, snippets, groups and known-hosts counts all
      match what was there before, and that connecting still works.
    - Confirm the original was **renamed** to `sshetu.db.moved` and not
      deleted, and that Settings → Diagnostics records the move rather than an
      error.
    - Relaunch. The second launch must not touch Documents again.
    A debug build proves none of this — a debug build has its own database and
    has never lived in Documents.
14. After release: Play Console → **Android vitals → excessive partial wake
    locks** (S8).

---

## What is unverified

Stated plainly, because none of it was checked and some of it could still be a
blocker.

- **Nothing in this branch was built or run.** No release or profile build of
  the app was made and the app was not launched — the brief forbade it, since
  release and profile builds open the user's real data. So the manifest,
  plist and entitlement changes above are verified by reading and by tests, not
  by a build. In particular: the `PrivacyInfo.xcprivacy` wiring into
  `ios/Runner.xcodeproj/project.pbxproj` is four lines added by script with the
  anchors matched exactly once each and braces re-balanced afterwards, and a
  test asserts the file is in the Runner Resources phase — but **no Xcode build
  has opened that project since**. Open it on a Mac once and confirm the file
  appears under Runner with Target Membership ticked.
- **iOS and macOS local-network behaviour** was not exercised. The purpose
  strings are present; that the prompt appears and that a LAN host connects
  after accepting it needs a device.
- **`allowBackup="false"` and the extraction rules** were not exercised. The
  manifest merge and the rules file are asserted by test; that Android honours
  them needs `bmgr` on a device.
- **Everything behind a console** — Data safety, content rating, App Privacy,
  age rating, export compliance, the special-use declaration, the signing
  secrets — cannot be read from a repository. The answers above are what to
  enter; whether they *were* entered is the owner's to confirm.
- **`android/key.properties` was not opened.** Its absence was checked; its
  contents were not read, moved or logged, and no signing configuration was
  changed.
- **The privacy-policy URL, the support URL and the marketing URL** do not
  exist yet, so none of them could be fetched. A 404 at either of the first two
  is a guaranteed rejection on both stores — fetch them once they are up.
- **Play listing character limits** were not re-fetched; the copy is
  placeholder anyway, so check the current limits when the real text is
  written.

---

## Gates

Run in this branch after the changes above. Output captured to a file and the
exit code read from the run, per the rails.

| Gate | Exit |
| --- | --- |
| `dart format --output=none --set-exit-if-changed lib test` | 0 |
| `flutter analyze` | 0 — "No issues found!" |
| `flutter test --exclude-tags live` | 0 |
