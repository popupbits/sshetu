# Agent tooling

`.mcp.json` in the project root declares the MCP servers an agent gets when it
opens this repo. Project-scoped, so it travels with the code — a teammate or a
CI agent gets the same tools without configuring anything.

## dart

Ships **inside the Dart SDK** (`dart mcp-server`), so there is nothing to
install and nothing to keep up to date separately.

It is the difference between an agent reasoning about this app and actually
running it: `analyze_files`, `run_tests`, `hot_reload`, `hot_restart`,
`launch_app`, `list_devices`, `get_runtime_errors`, `widget_inspector`,
`pub`, `pub_dev_search`.

Worth knowing: two of the worst `material_ui` failure modes — losing route
transitions, and a theme silently falling back — pass `flutter analyze` and
fail only when the app runs. Being able to launch it and read its runtime
errors is what catches those.

## Android CLI (not MCP, but check for it)

Google's `android` command, in the SDK's `cmdline-tools/latest/bin`. Not
declared here — it is a normal executable — but if it is on PATH, prefer it
over raw `adb`:

- `android info` — SDK path, connected devices, configuration
- `android emulator list` / `start <avd>` — boot a device without Android Studio
- `android screen capture` — a device screenshot straight to PNG
- `android layout` — the running app's layout tree
- `android docs search "..."` — official Android documentation
- `android sdk install` — fix a missing platform or build-tools package

`flutter run` and `flutter build` remain the build path for this project; the
Android CLI complements them for device, emulator, SDK and inspection work.
Pass `--no-metrics` to opt out of its usage reporting.

## Skills

`.claude/skills/` holds skills scoped to this project. They load on demand when
a task matches their description, rather than sitting in the context window.

These are **copies**, generated with the project. They do not update themselves.
If one is wrong or out of date, fix it here — this repo owns it now.
