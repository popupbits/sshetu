# Google Play checklist

Play rejects less often at review than Apple, but blocks harder at **upload**
and can suspend after publication for policy mismatches. Most Play problems
are declaration problems, not code problems.

Re-fetch current requirements at audit time — Play's API-level deadlines move
every year.

## Blocks at upload

### Target API level
New apps and updates must target at least Play's current required API level.
**Fetch the current requirement and deadline** — do not report from memory.
Apps below the threshold cannot be uploaded at all.

Extensions are sometimes available via Play Console, but only until a stated
cutoff.

### Signing
A debug-signed AAB is rejected with a confusing error. Confirm release signing
is actually configured — many Flutter templates fall back to debug signing
when `key.properties` is absent, which builds fine locally and fails at upload.

### Version code
Must exceed every previously uploaded code, including builds uploaded outside
your git history.

### Missing listing assets
Play will not publish without: title, short description, full description,
icon (512×512), feature graphic (1024×500), and **at least 2 phone
screenshots**.

## Declarations (need a human — mark UNVERIFIED)

### Data safety form
Required for every app. Must accurately describe collection, use, and sharing.
Requires a privacy policy URL to submit. Google holds the developer
responsible for accuracy and for keeping it current — and now explicitly
extends this to data handled by **third-party AI integrations**.

Cross-check the answers against the app's actual permissions and network
calls. A Data safety form that says "no data collected" while the app has
`INTERNET` + analytics is a suspension risk.

### Content rating
Unrated apps are not allowed. Complete the IARC questionnaire.

### Privacy policy
Active, publicly accessible, non-geofenced URL. **Not a PDF.** Required in the
Play Console field, and in-app if the app handles sensitive data.

### Permissions declarations
Sensitive permissions need an in-console declaration and often a demo video:

- `ACCESS_BACKGROUND_LOCATION` — needs a declaration and a strong use case
- `QUERY_ALL_PACKAGES` — only for permitted uses (launchers, antivirus,
  file managers); otherwise removal
- `SCHEDULE_EXACT_ALARM` — needs justification on Android 13+
- `MANAGE_EXTERNAL_STORAGE` — heavily restricted
- SMS/Call Log — almost always rejected outside default-handler apps

### Account deletion
Apps offering account creation must provide in-app deletion **and** a
web-accessible deletion route for users who have uninstalled. Declared in
Play Console under Data safety.

### Ads and families policy
If the app targets or appeals to children, Families policy applies: certified
ad SDKs only, no behavioural targeting, and a stricter content review.

## Common post-publication suspensions

- Data safety declaration drifting out of sync with app behaviour after an
  update
- Permissions added by a plugin upgrade without updating declarations
- Broken or expired privacy policy URL
- Store listing claims the app doesn't deliver ("misleading claims")
