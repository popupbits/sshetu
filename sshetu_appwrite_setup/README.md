# sshetu_appwrite_setup

Creates the Appwrite schema SSHetu's sync engine and secret vault expect,
exactly as `../docs/appwrite-schema.md` describes it.

A separate package on purpose. The app must never depend on the server SDK,
and a server API key must never be reachable from anything that ships to a
device — which is also why the app provisions nothing itself.

## Use

```sh
cp .env.example .env        # then fill in APPWRITE_API_KEY
dart pub get
dart run bin/setup_appwrite.dart --check    # what is missing; writes nothing
dart run bin/setup_appwrite.dart            # create or finish the job
```

The API key needs **`databases.read` and `databases.write` and nothing else**.
Never use a key with account or user scopes for this.

Flags (`--endpoint`, `--project`, `--database`, `--api-key`) beat `.env` when
both are set, so a one-off against a second project needs no file.

## What it does

Creates the database if absent, then five tables — `host_groups`,
`identities`, `hosts`, `tunnels`, `secrets` — with their columns, a `key`
index on `updated_at` for the four synced ones, and row-level security with
`create` for signed-in users as the only table-level grant. `secrets.value` is
created with Appwrite's `encrypt` option; read the schema doc's note on what
that does and does not protect against before relying on it.

Nothing here is destructive. Every step either creates what is missing or sees
a 409 and moves on, so it is safe to re-run against a project that is already
correct, and it finishes a half-built one.

`--check` exists because the failure this prevents is a *partially* created
schema: one missing column makes every push fail with a message about that
column and nothing about the cause.

## Exit codes

| Code | Meaning |
|---|---|
| 0 | done, or `--check` found nothing missing |
| 1 | Appwrite refused something |
| 64 | bad usage — no API key |

Worth stating because `--check` is meant to be usable in a script, and a tool
whose exit code lies is worse than no tool.

## After it runs

Point the app at the project:

```sh
flutter run \
  --dart-define=APPWRITE_PROJECT=<project> \
  --dart-define=APPWRITE_DATABASE=<database>
```

Until that happens the app is local-only: `SyncScheduler` still runs on its
triggers and reports the failure in Settings, which is the intended behaviour
rather than a bug.
