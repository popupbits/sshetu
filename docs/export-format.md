# SSHetu export format (`sshetu-export`, version 1)

Settings → Hosts → **Export as JSON (no secrets)** writes one UTF-8 JSON file
holding every piece of SSHetu configuration a person would want to take
elsewhere. **Import from JSON** reads it back. This document is the contract
for that file: other tools may read and write it, and SSHetu will keep reading
version 1 for as long as it exists.

The code is `lib/features/export/domain/portable_export.dart`; the tests pin
the exact output (`test/export/fixtures/export_v1.json`).

## What is not in it

**No secret, ever.** Private keys, key passphrases and saved passwords are
never written, whatever the settings. SSH identities appear only as their
public key and fingerprint. `containsSecrets` is always `false` and exists so
the file says so itself.

To keep keys and passwords as well, use the **encrypted backup**
(Settings → Backup), which is a different file (`.sshetu-backup`), sealed under
a passphrase with Argon2id and XSalsa20-Poly1305. See `PROJECT.md` §12.

Also absent: app settings (theme, fonts, the terminal defaults), session
history and the on-device error log. They are preferences of one device, not
configuration of servers.

## Shape

The file is pretty-printed with two-space indentation and ends in a newline.
Keys appear in the order listed below, every key is present (`null` rather than
omitted), and every list is sorted — by `id`, or by `hostname` then `port` for
`knownHosts` — so the same configuration always produces the same bytes.

Readers must not depend on that order or on whitespace.

```json
{
  "format": "sshetu-export",
  "version": 1,
  "exportedAt": "2026-09-22T10:00:00.000Z",
  "app": "1.0.0+1",
  "containsSecrets": false,
  "groups": [],
  "identities": [],
  "hosts": [],
  "tunnels": [],
  "snippets": [],
  "knownHosts": []
}
```

| Key | Type | Meaning |
|---|---|---|
| `format` | string | Always `"sshetu-export"`. Anything else is refused. |
| `version` | integer | The format version. See [Versioning](#versioning). |
| `exportedAt` | timestamp | When the file was written. |
| `app` | string | The SSHetu build that wrote it (`version+build`). Informational only. |
| `containsSecrets` | boolean | Always `false`. |

### Conventions

- **Timestamps** are ISO 8601 in UTC with milliseconds:
  `2026-01-31T09:15:00.000Z`. SSHetu stores milliseconds, so a round trip is
  exact.
- **Ids** are opaque strings. They are preserved on export and import so that
  re-importing a file updates what it created rather than duplicating it.
  Another tool generating a file may use any unique string.
- **References** between entries are by id (`groupId`, `identityId`,
  `jumpHostId`, `hostId`).

### `groups[]`

A folder of hosts.

| Key | Type | Notes |
|---|---|---|
| `id` | string | required |
| `name` | string | required |
| `sortOrder` | integer | position among groups; default `0` |
| `createdAt`, `updatedAt` | timestamp | |

### `identities[]`

An SSH key the exporting device holds — **public half only**.

| Key | Type | Notes |
|---|---|---|
| `id` | string | required |
| `label` | string | required |
| `keyType` | string | `ssh-ed25519`, `ecdsa-sha2-nistp256`, `ssh-rsa`, … or `unknown` |
| `publicKey` | string \| null | OpenSSH one-line public key |
| `fingerprint` | string \| null | `SHA256:<base64, no padding>`, as `ssh-keygen -lf` prints. Computed from `publicKey` when not recorded. |
| `hasPassphrase` | boolean | whether the private key is encrypted |
| `origin` | string | `generated`, `imported` or `sshConfig` |
| `createdAt`, `updatedAt` | timestamp | |

### `hosts[]`

A saved server.

| Key | Type | Notes |
|---|---|---|
| `id` | string | required |
| `label` | string | required; what the user calls it |
| `hostname` | string | required |
| `port` | integer | 1–65535; default `22` |
| `username` | string | required |
| `authMethod` | string | `publicKey`, `password` or `agent`; unknown values read as `publicKey` |
| `groupId` | string \| null | a `groups[].id` |
| `identityId` | string \| null | an `identities[].id` |
| `identityFingerprint` | string \| null | that identity's fingerprint, repeated here so a file whose `identities` were removed can still be linked |
| `jumpHostId` | string \| null | another `hosts[].id` to connect through (`ProxyJump`) |
| `allowLegacyAlgorithms` | boolean | re-enables SHA-1 key exchange, `ssh-rsa` host keys and CBC ciphers for this host only |
| `forwardAgent` | boolean | `ForwardAgent` |
| `tmuxMode` | string | keep this host's sessions running on the server in tmux: `default` (follow the app setting), `always` or `never`. Missing or unknown values read as `default`. |
| `keepaliveSeconds` | integer | `0` turns keepalives off; default `30` |
| `startupCommand` | string \| null | run once the shell opens |
| `terminalTheme` | string \| null | a terminal colour preset id; `null` follows the app |
| `fontSize` | number \| null | terminal font size; `null` follows the app |
| `notes` | string \| null | free text |
| `tags` | string[] | no commas; at most 32 characters each |
| `envVars` | object | variable name → value. Names match `^[A-Za-z_][A-Za-z0-9_]*$`; values contain no line break or NUL. Entries breaking either rule are dropped on import. |
| `lastConnectedAt` | timestamp \| null | |
| `createdAt`, `updatedAt` | timestamp | |

A host with `authMethod: "password"` arrives without its password; SSHetu asks
for it on first connect.

### `tunnels[]`

A saved port forward.

| Key | Type | Notes |
|---|---|---|
| `id` | string | required |
| `hostId` | string | required; the `hosts[].id` it runs over |
| `label` | string | required |
| `kind` | string | `local` (`ssh -L`), `remote` (`ssh -R`) or `dynamic` (`ssh -D`, SOCKS) |
| `listenHost` | string | default `127.0.0.1` |
| `listenPort` | integer | 1–65535, required |
| `targetHost` | string \| null | required for `local` and `remote`; `null` for `dynamic` |
| `targetPort` | integer \| null | as `targetHost` |
| `autoStart` | boolean | start when the app opens |
| `createdAt`, `updatedAt` | timestamp | |

### `snippets[]`

A saved command.

| Key | Type | Notes |
|---|---|---|
| `id` | string | required |
| `label` | string | required |
| `body` | string | required; may span lines and hold `{{name}}` placeholders |
| `description` | string \| null | |
| `tags` | string[] | |
| `sortOrder` | integer | |
| `createdAt`, `updatedAt` | timestamp | |

### `knownHosts[]`

A host key the exporting device trusts.

| Key | Type | Notes |
|---|---|---|
| `hostname` | string | required. A hashed entry imported from an OpenSSH `known_hosts` keeps its `\|1\|salt\|hash` form here, with `port` `0`. |
| `port` | integer | |
| `keyType` | string | required, e.g. `ssh-ed25519` |
| `fingerprint` | string | required, `SHA256:<base64>` |
| `trustedAt` | timestamp | |

## Importing

SSHetu shows a preview and writes nothing until the user confirms; then it
writes everything in **one database transaction**.

- **Hosts** are matched by `id` first — the same id updates the saved host (or
  is reported as already up to date). Otherwise a host with the same
  `username`, `hostname` (case-insensitive) and `port` is a **conflict**, and
  the user chooses once for all conflicts: **Merge** (the saved host takes the
  file's settings and keeps its own id, tunnels and saved password) or **Add
  as new** (the file's host is added beside it).
- **Keys** are matched by **fingerprint** — a key generated or imported on two
  devices has two ids and one fingerprint. Only when the file gives no
  fingerprint at all is a key with the same id on this device used. A host
  whose key this device has is linked to it; a host whose key it lacks is
  imported without one, and the preview lists the missing keys — to be
  brought over with the encrypted backup, *Send to a device*, or by pasting
  the key — and the hosts that use each. No identity row is created from an
  export: a key with no private half would look usable and not be.
- **Groups** are matched by id, then by name.
- **Tunnels** follow their host (including onto a merged host); one whose host
  is neither in the file nor on the device is skipped, and one identical to a
  forward the host already has is not duplicated.
- **Snippets** are matched by id; one with the same label and body as a saved
  snippet is not duplicated.
- **Known-host pins** are added when the device has none for that address. A
  pin that disagrees with the device's is **left out**: an import never
  replaces a trust decision.

Required fields that are missing or of the wrong type make the whole file
invalid, and the message names the field (`hosts[3].hostname`). Unknown keys
are ignored. A missing list means an empty one. Missing `createdAt` /
`updatedAt` / `trustedAt` default to `exportedAt`.

## Versioning

`version` is an integer and changes only when this contract changes in a way an
older reader would misread.

- A reader **accepts** every version up to the newest it knows.
- A reader **refuses** a newer version, and says so: *"This export was written
  by a newer version of SSHetu (format version 2; this build reads up to
  version 1). Update SSHetu and try again."* Guessing at a format it does not
  know could silently drop or misapply settings.
- Adding an optional key that older readers can ignore does not need a new
  version; readers must ignore unknown keys.

## Related imports

- **OpenSSH** (`~/.ssh/config` and keys): Settings → Hosts → Import from
  OpenSSH.
- **PuTTY**: Settings → Hosts → Import from PuTTY. On Windows it reads
  `HKCU\Software\SimonTatham\PuTTY\Sessions` through `reg.exe export`; on any
  platform it accepts a `.reg` file exported from that key. SSH sessions only;
  `.ppk` keys are reported (convert them with PuTTYgen → *Conversions → Export
  OpenSSH key*), proxies are reported as not imported, and `PortForwardings`
  become tunnels with auto-start off, for review.
