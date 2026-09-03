# Mechanical repo audit

Checks that can be answered from files alone. Run these first — they're cheap
and they catch most real blockers.

Paths assume this workspace's convention: Flutter app at repo root, fastlane
under `android/fastlane/` with metadata at
`android/fastlane/metadata/android/<locale>/`.

## Version and build

```bash
grep -m1 '^version:' pubspec.yaml
```

- Build number must be **higher than anything already uploaded**. A reused
  version code is rejected at upload with "Version code N has already been
  used" — and the last `chore(release)` commit is not proof, since builds are
  sometimes uploaded outside git.
- Version *name* may repeat; the *code* may not.

## Android target API

```bash
grep -rnE 'targetSdk|compileSdk' android/app/build.gradle*
```

Compare against the current Play requirement (fetch it — see SKILL.md).
Flutter projects often read `flutter.targetSdkVersion`, so also check the
Flutter SDK's resolved value if it's indirect.

## Android permissions vs. declared behaviour

```bash
grep -oE 'android:name="android.permission.[A-Z_]+"' android/app/src/main/AndroidManifest.xml | sort -u
```

Every permission must be (a) actually used and (b) consistent with the Data
safety declaration. Unused permissions inherited from a plugin are a common
rejection. Flag any of these for explicit justification:
`ACCESS_FINE_LOCATION`, `ACCESS_BACKGROUND_LOCATION`, `READ_CONTACTS`,
`READ_MEDIA_*`, `QUERY_ALL_PACKAGES`, `SCHEDULE_EXACT_ALARM`,
`POST_NOTIFICATIONS`, `RECORD_AUDIO`, `CAMERA`.

`QUERY_ALL_PACKAGES` needs a declared permitted use — launchers qualify, most
apps do not.

## iOS purpose strings

```bash
grep -nE 'NS[A-Za-z]+UsageDescription' ios/Runner/Info.plist
```

Every permission-triggering API needs a purpose string, and it must describe
the *specific* use (Guideline 5.1.1(ii)). Generic strings like "This app needs
camera access" are rejected. Cross-check against the plugins in `pubspec.yaml`
— `image_picker` needs camera + photo library, `flutter_contacts` needs
contacts, `geolocator` needs location, `record`/`speech_to_text` need
microphone.

## iOS privacy manifest

```bash
ls ios/Runner/PrivacyInfo.xcprivacy
```

Required since May 2024 for apps using "required reason" APIs, and for listed
third-party SDKs. Flutter apps commonly trip this via `shared_preferences`
(UserDefaults), `path_provider` (file timestamps), and any analytics SDK.
Missing manifest → App Store Connect rejects the upload, not the review.

## iOS export compliance

```bash
grep -n 'ITSAppUsesNonExemptEncryption' ios/Runner/Info.plist
```

Absent means App Store Connect asks on every single upload. Setting it to
`false` (for apps using only standard HTTPS) removes that friction.

## Store listing completeness

```bash
find android/fastlane/metadata -name '*.txt' | sort
find android/fastlane/metadata -path '*images*' \( -name '*.png' -o -name '*.jpg' \) | sort
```

Required per locale:

- `title.txt`, `short_description.txt`, `full_description.txt`
- feature graphic (1024×500) and icon (512×512)
- **at least 2 phone screenshots** — Play will not let you publish without them

Check lengths against the current limits (verify): Play title ~30 chars,
short description ~80, full description ~4000. A file that exceeds the limit
fails at upload.

An empty `metadata/` directory means the app cannot be published at all,
regardless of how good the build is.

## Changelogs

```bash
ls android/fastlane/metadata/android/*/changelogs/
```

Play needs release notes for the version code being shipped. Missing notes
for the current code is a common upload failure.

## Privacy policy reachability

Extract the privacy policy URL (from the listing metadata, the app's about
screen, or the landing site) and actually fetch it. Requirements:

- publicly reachable, not geofenced, **not a PDF**
- describes the data the app actually collects
- linked both in the store listing *and* in-app (Guideline 5.1.1(i))

A 404 privacy policy is a guaranteed rejection on both stores.

## Account deletion

```bash
grep -rn 'deleteAccount\|delete_account\|accountDeletion' lib/ | head
```

If the app supports account creation, it must offer **in-app account
deletion** (Guideline 5.1.1(v)) and Play requires a deletion path including a
web route for users who've uninstalled. An app with auth and no deletion flow
is a blocker on both stores.

## Third-party sign-in

```bash
grep -rn 'google_sign_in\|signInWithGoogle\|FacebookAuth\|sign_in_with_apple' lib/ | head
```

If the app offers Google/Facebook login on iOS, Guideline 4.8 requires an
equivalent privacy-preserving option — in practice Sign in with Apple —
unless an exception applies (own-auth-only, education, enterprise).

## Debug and placeholder leftovers

```bash
grep -rn 'TODO\|FIXME\|lorem ipsum\|placeholder\|example.com' android/fastlane/metadata/ 2>/dev/null
grep -rn 'debugShowCheckedModeBanner: true' lib/
grep -rn 'http://' lib/ android/app/src/main/AndroidManifest.xml | grep -v localhost
```

Guideline 2.1 rejects placeholder text and non-functional URLs. Cleartext
`http://` endpoints also trip Play's security review.
