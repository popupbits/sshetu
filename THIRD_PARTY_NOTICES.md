# Third-party notices

SSHetu is MIT (see [LICENSE](LICENSE)). It is built on the
packages below, each under its own licence. This file is
generated — run `dart run tool/third_party_notices.dart` after
changing a dependency, and `--check` to fail a build on a stale
one.

_Generated from `pubspec.lock`; dev-only dependencies are not
listed because they are not shipped._

## Bundled in the repository

These are redistributed as files here, not fetched at build
time, so their licence text travels with this repository.

| What | Upstream | Licence | Text |
| --- | --- | --- | --- |
| `packages/xterm2/` — vendored fork of xterm2 5.3.0 | <https://github.com/SoFluffyOS/xterm2> | MIT, © 2020 xuty | [`packages/xterm2/LICENSE`](packages/xterm2/LICENSE) |
| JetBrains Mono | <https://github.com/JetBrains/JetBrainsMono> | OFL-1.1 | [`assets/fonts/jetbrains_mono/OFL.txt`](assets/fonts/jetbrains_mono/OFL.txt) |
| Fira Code | <https://github.com/tonsky/FiraCode> | OFL-1.1 | [`assets/fonts/fira_code/OFL.txt`](assets/fonts/fira_code/OFL.txt) |
| Source Code Pro | <https://github.com/adobe-fonts/source-code-pro> | OFL-1.1 | [`assets/fonts/source_code_pro/OFL.txt`](assets/fonts/source_code_pro/OFL.txt) |
| IBM Plex Mono | <https://github.com/IBM/plex> | OFL-1.1 | [`assets/fonts/ibm_plex_mono/OFL.txt`](assets/fonts/ibm_plex_mono/OFL.txt) |

The four font licences are also registered with Flutter at
startup (`lib/core/theme/terminal_fonts.dart`), so the OFL text
travels with the installed app as the licence asks, and shows
under *Settings → About → Open-source licences*.

## Direct dependencies

Declared in `pubspec.yaml`.

| Package | Version | Licence | Source |
| --- | --- | --- | --- |
| `async` | 2.13.1 | BSD-3-Clause | https://pub.dev/packages/async |
| `connectivity_plus` | 7.3.1 | BSD-3-Clause | https://pub.dev/packages/connectivity_plus |
| `crypto` | 3.0.7 | BSD-3-Clause | https://pub.dev/packages/crypto |
| `cryptography` | 2.9.0 | Apache-2.0 | https://pub.dev/packages/cryptography |
| `cupertino_icons` | 1.0.9 | MIT | https://pub.dev/packages/cupertino_icons |
| `dartssh2` | 4.0.0 | MIT | https://pub.dev/packages/dartssh2 |
| `desktop_drop` | 0.8.4 | Apache-2.0 | https://pub.dev/packages/desktop_drop |
| `file_selector` | 1.1.0 | BSD-3-Clause | https://pub.dev/packages/file_selector |
| `flutter_riverpod` | 3.4.2 | MIT | https://pub.dev/packages/flutter_riverpod |
| `flutter_secure_storage` | 11.0.0 | BSD-3-Clause | https://pub.dev/packages/flutter_secure_storage |
| `go_router` | 17.5.0 | BSD-3-Clause | https://pub.dev/packages/go_router |
| `google_fonts` | 8.2.1 | BSD-3-Clause | https://pub.dev/packages/google_fonts |
| `in_app_review` | 2.0.12 | MIT | https://pub.dev/packages/in_app_review |
| `in_app_update` | 5.0.0 | MIT | https://pub.dev/packages/in_app_update |
| `intl` | 0.20.3 | BSD-3-Clause | https://pub.dev/packages/intl |
| `local_auth` | 3.0.2 | BSD-3-Clause | https://pub.dev/packages/local_auth |
| `marionette_flutter` | 0.6.0 | Apache-2.0 | https://pub.dev/packages/marionette_flutter |
| `material_ui` | 1.1.1 | BSD-3-Clause | https://pub.dev/packages/material_ui |
| `mobile_scanner` | 7.4.0 | BSD-3-Clause | https://pub.dev/packages/mobile_scanner |
| `package_info_plus` | 10.2.1 | BSD-3-Clause | https://pub.dev/packages/package_info_plus |
| `path` | 1.9.1 | BSD-3-Clause | https://pub.dev/packages/path |
| `path_provider` | 2.1.6 | BSD-3-Clause | https://pub.dev/packages/path_provider |
| `picons` | 3.0.1 | MIT | https://pub.dev/packages/picons |
| `pinenacl` | 0.6.0 | MIT | https://pub.dev/packages/pinenacl |
| `pointycastle` | 4.0.0 | MIT | https://pub.dev/packages/pointycastle |
| `qr_flutter` | 4.1.0 | BSD-3-Clause | https://pub.dev/packages/qr_flutter |
| `share_plus` | 13.3.0 | BSD-3-Clause | https://pub.dev/packages/share_plus |
| `shared_preferences` | 2.5.5 | BSD-3-Clause | https://pub.dev/packages/shared_preferences |
| `sqflite` | 2.4.3 | BSD-2-Clause | https://pub.dev/packages/sqflite |
| `sqflite_common_ffi` | 2.4.2+1 | BSD-2-Clause | https://pub.dev/packages/sqflite_common_ffi |
| `url_launcher` | 6.3.2 | BSD-3-Clause | https://pub.dev/packages/url_launcher |
| `wakelock_plus` | 1.8.0 | BSD-3-Clause | https://pub.dev/packages/wakelock_plus |
| `xterm2` | 5.3.0 | MIT | packages/xterm2/LICENSE |

## Transitive dependencies

Pulled in by the packages above. Listed for completeness; each one ships its own licence, which Flutter also collects into the in-app licence page.

| Package | Version | Licence | Source |
| --- | --- | --- | --- |
| `_fe_analyzer_shared` | 103.0.0 | BSD-3-Clause | https://pub.dev/packages/_fe_analyzer_shared |
| `analyzer` | 13.3.0 | BSD-3-Clause | https://pub.dev/packages/analyzer |
| `args` | 2.7.0 | BSD-3-Clause | https://pub.dev/packages/args |
| `asn1lib` | 1.6.5 | BSD-2-Clause | https://pub.dev/packages/asn1lib |
| `boolean_selector` | 2.1.2 | BSD-3-Clause | https://pub.dev/packages/boolean_selector |
| `characters` | 1.4.1 | BSD-3-Clause | https://pub.dev/packages/characters |
| `cli_config` | 0.2.0 | BSD-3-Clause | https://pub.dev/packages/cli_config |
| `clock` | 1.1.3 | Apache-2.0 | https://pub.dev/packages/clock |
| `code_assets` | 1.2.1 | BSD-3-Clause | https://pub.dev/packages/code_assets |
| `collection` | 1.19.1 | BSD-3-Clause | https://pub.dev/packages/collection |
| `connectivity_plus_platform_interface` | 2.1.0 | BSD-3-Clause | https://pub.dev/packages/connectivity_plus_platform_interface |
| `convert` | 3.1.2 | BSD-3-Clause | https://pub.dev/packages/convert |
| `coverage` | 1.15.1 | BSD-3-Clause | https://pub.dev/packages/coverage |
| `cross_file` | 0.3.5+5 | BSD-3-Clause | https://pub.dev/packages/cross_file |
| `cupertino_ui` | 1.0.2 | BSD-3-Clause | https://pub.dev/packages/cupertino_ui |
| `dbus` | 0.7.15 | MPL-2.0 | https://pub.dev/packages/dbus |
| `equatable` | 2.1.0 | MIT | https://pub.dev/packages/equatable |
| `fake_async` | 1.3.3 | Apache-2.0 | https://pub.dev/packages/fake_async |
| `ffi` | 2.2.0 | BSD-3-Clause | https://pub.dev/packages/ffi |
| `ffi_leak_tracker` | 0.1.2 | BSD-3-Clause | https://pub.dev/packages/ffi_leak_tracker |
| `file` | 7.0.1 | BSD-3-Clause | https://pub.dev/packages/file |
| `file_selector_android` | 0.5.2+10 | Apache-2.0 | https://pub.dev/packages/file_selector_android |
| `file_selector_ios` | 0.5.3+6 | BSD-3-Clause | https://pub.dev/packages/file_selector_ios |
| `file_selector_linux` | 0.9.4+1 | BSD-3-Clause | https://pub.dev/packages/file_selector_linux |
| `file_selector_macos` | 0.9.5+1 | BSD-3-Clause | https://pub.dev/packages/file_selector_macos |
| `file_selector_platform_interface` | 2.7.0 | BSD-3-Clause | https://pub.dev/packages/file_selector_platform_interface |
| `file_selector_web` | 0.9.5 | BSD-3-Clause | https://pub.dev/packages/file_selector_web |
| `file_selector_windows` | 0.9.3+6 | BSD-3-Clause | https://pub.dev/packages/file_selector_windows |
| `fixnum` | 1.1.1 | BSD-3-Clause | https://pub.dev/packages/fixnum |
| `flutter_plugin_android_lifecycle` | 2.0.35 | BSD-3-Clause | https://pub.dev/packages/flutter_plugin_android_lifecycle |
| `flutter_secure_storage_darwin` | 0.4.0 | BSD-3-Clause | https://pub.dev/packages/flutter_secure_storage_darwin |
| `flutter_secure_storage_linux` | 3.0.2 | BSD-3-Clause | https://pub.dev/packages/flutter_secure_storage_linux |
| `flutter_secure_storage_platform_interface` | 2.0.3 | BSD-3-Clause | https://pub.dev/packages/flutter_secure_storage_platform_interface |
| `flutter_secure_storage_web` | 2.1.1 | BSD-3-Clause | https://pub.dev/packages/flutter_secure_storage_web |
| `flutter_secure_storage_windows` | 4.2.2 | BSD-3-Clause | https://pub.dev/packages/flutter_secure_storage_windows |
| `frontend_server_client` | 4.0.0 | BSD-3-Clause | https://pub.dev/packages/frontend_server_client |
| `glob` | 2.2.0 | BSD-3-Clause | https://pub.dev/packages/glob |
| `hooks` | 2.0.2 | BSD-3-Clause | https://pub.dev/packages/hooks |
| `http` | 1.6.0 | BSD-3-Clause | https://pub.dev/packages/http |
| `http_multi_server` | 3.2.2 | BSD-3-Clause | https://pub.dev/packages/http_multi_server |
| `http_parser` | 4.1.2 | BSD-3-Clause | https://pub.dev/packages/http_parser |
| `in_app_review_platform_interface` | 2.0.5 | MIT | https://pub.dev/packages/in_app_review_platform_interface |
| `io` | 1.1.0 | BSD-3-Clause | https://pub.dev/packages/io |
| `jni` | 1.0.3 | BSD-3-Clause | https://pub.dev/packages/jni |
| `jni_flutter` | 1.0.3 | BSD-3-Clause | https://pub.dev/packages/jni_flutter |
| `jni_util` | 1.0.0 | BSD-3-Clause | https://pub.dev/packages/jni_util |
| `leak_tracker` | 11.0.2 | BSD-3-Clause | https://pub.dev/packages/leak_tracker |
| `leak_tracker_flutter_testing` | 3.0.10 | BSD-3-Clause | https://pub.dev/packages/leak_tracker_flutter_testing |
| `leak_tracker_testing` | 3.0.2 | BSD-3-Clause | https://pub.dev/packages/leak_tracker_testing |
| `listen` | 1.0.1 | BSD-3-Clause | https://pub.dev/packages/listen |
| `local_auth_android` | 2.0.10 | BSD-3-Clause | https://pub.dev/packages/local_auth_android |
| `local_auth_darwin` | 2.0.4 | BSD-3-Clause | https://pub.dev/packages/local_auth_darwin |
| `local_auth_platform_interface` | 1.1.0 | BSD-3-Clause | https://pub.dev/packages/local_auth_platform_interface |
| `local_auth_windows` | 2.0.2 | BSD-3-Clause | https://pub.dev/packages/local_auth_windows |
| `logging` | 1.3.0 | BSD-3-Clause | https://pub.dev/packages/logging |
| `matcher` | 0.12.20 | BSD-3-Clause | https://pub.dev/packages/matcher |
| `material_color_utilities` | 0.13.0 | Apache-2.0 | https://pub.dev/packages/material_color_utilities |
| `meta` | 1.18.3 | BSD-3-Clause | https://pub.dev/packages/meta |
| `mime` | 2.1.0 | BSD-3-Clause | https://pub.dev/packages/mime |
| `native_toolchain_c` | 0.19.2 | BSD-3-Clause | https://pub.dev/packages/native_toolchain_c |
| `nm` | 0.5.0 | MPL-2.0 | https://pub.dev/packages/nm |
| `node_preamble` | 2.0.2 | MIT | https://pub.dev/packages/node_preamble |
| `objective_c` | 9.5.0 | BSD-3-Clause | https://pub.dev/packages/objective_c |
| `package_config` | 2.2.0 | BSD-3-Clause | https://pub.dev/packages/package_config |
| `package_info_plus_platform_interface` | 4.1.0 | BSD-3-Clause | https://pub.dev/packages/package_info_plus_platform_interface |
| `path_provider_android` | 2.3.1 | BSD-3-Clause | https://pub.dev/packages/path_provider_android |
| `path_provider_foundation` | 2.6.0 | BSD-3-Clause | https://pub.dev/packages/path_provider_foundation |
| `path_provider_linux` | 2.2.2 | BSD-3-Clause | https://pub.dev/packages/path_provider_linux |
| `path_provider_platform_interface` | 2.1.3 | BSD-3-Clause | https://pub.dev/packages/path_provider_platform_interface |
| `path_provider_windows` | 2.3.0 | BSD-3-Clause | https://pub.dev/packages/path_provider_windows |
| `petitparser` | 7.0.2 | MIT | https://pub.dev/packages/petitparser |
| `platform` | 3.1.6 | BSD-3-Clause | https://pub.dev/packages/platform |
| `plugin_platform_interface` | 2.1.8 | BSD-3-Clause | https://pub.dev/packages/plugin_platform_interface |
| `pool` | 1.5.3 | BSD-3-Clause | https://pub.dev/packages/pool |
| `pub_semver` | 2.2.1 | BSD-3-Clause | https://pub.dev/packages/pub_semver |
| `qr` | 3.0.2 | BSD-3-Clause | https://pub.dev/packages/qr |
| `quiver` | 3.2.2 | Apache-2.0 | https://pub.dev/packages/quiver |
| `record_use` | 0.6.0 | BSD-3-Clause | https://pub.dev/packages/record_use |
| `riverpod` | 3.4.2 | MIT | https://pub.dev/packages/riverpod |
| `share_plus_platform_interface` | 7.2.0 | BSD-3-Clause | https://pub.dev/packages/share_plus_platform_interface |
| `shared_preferences_android` | 2.4.28 | BSD-3-Clause | https://pub.dev/packages/shared_preferences_android |
| `shared_preferences_foundation` | 2.5.7 | BSD-3-Clause | https://pub.dev/packages/shared_preferences_foundation |
| `shared_preferences_linux` | 2.4.1 | BSD-3-Clause | https://pub.dev/packages/shared_preferences_linux |
| `shared_preferences_platform_interface` | 2.4.2 | BSD-3-Clause | https://pub.dev/packages/shared_preferences_platform_interface |
| `shared_preferences_web` | 2.4.3 | BSD-3-Clause | https://pub.dev/packages/shared_preferences_web |
| `shared_preferences_windows` | 2.4.1 | BSD-3-Clause | https://pub.dev/packages/shared_preferences_windows |
| `shelf` | 1.4.2 | BSD-3-Clause | https://pub.dev/packages/shelf |
| `shelf_packages_handler` | 3.0.2 | BSD-3-Clause | https://pub.dev/packages/shelf_packages_handler |
| `shelf_static` | 1.1.3 | BSD-3-Clause | https://pub.dev/packages/shelf_static |
| `shelf_web_socket` | 3.0.0 | BSD-3-Clause | https://pub.dev/packages/shelf_web_socket |
| `source_map_stack_trace` | 2.1.2 | BSD-3-Clause | https://pub.dev/packages/source_map_stack_trace |
| `source_maps` | 0.10.14 | BSD-3-Clause | https://pub.dev/packages/source_maps |
| `source_span` | 1.10.2 | BSD-3-Clause | https://pub.dev/packages/source_span |
| `sqflite_android` | 2.4.3 | BSD-2-Clause | https://pub.dev/packages/sqflite_android |
| `sqflite_common` | 2.5.11 | BSD-2-Clause | https://pub.dev/packages/sqflite_common |
| `sqflite_darwin` | 2.4.3+1 | BSD-2-Clause | https://pub.dev/packages/sqflite_darwin |
| `sqflite_platform_interface` | 2.4.1 | BSD-2-Clause | https://pub.dev/packages/sqflite_platform_interface |
| `sqlite3` | 3.5.2 | MIT | https://pub.dev/packages/sqlite3 |
| `stack_trace` | 1.12.2 | BSD-3-Clause | https://pub.dev/packages/stack_trace |
| `state_notifier` | 1.0.0 | MIT | https://pub.dev/packages/state_notifier |
| `stream_channel` | 2.1.4 | BSD-3-Clause | https://pub.dev/packages/stream_channel |
| `string_scanner` | 1.4.1 | BSD-3-Clause | https://pub.dev/packages/string_scanner |
| `synchronized` | 3.4.1+2 | MIT | https://pub.dev/packages/synchronized |
| `term_glyph` | 1.2.2 | BSD-3-Clause | https://pub.dev/packages/term_glyph |
| `test` | 1.31.1 | BSD-3-Clause | https://pub.dev/packages/test |
| `test_api` | 0.7.12 | BSD-3-Clause | https://pub.dev/packages/test_api |
| `test_core` | 0.6.18 | BSD-3-Clause | https://pub.dev/packages/test_core |
| `typed_data` | 1.4.0 | BSD-3-Clause | https://pub.dev/packages/typed_data |
| `universal_platform` | 1.1.0 | MIT | https://pub.dev/packages/universal_platform |
| `url_launcher_android` | 6.3.33 | BSD-3-Clause | https://pub.dev/packages/url_launcher_android |
| `url_launcher_ios` | 6.4.2 | BSD-3-Clause | https://pub.dev/packages/url_launcher_ios |
| `url_launcher_linux` | 3.2.3 | BSD-3-Clause | https://pub.dev/packages/url_launcher_linux |
| `url_launcher_macos` | 3.2.6 | BSD-3-Clause | https://pub.dev/packages/url_launcher_macos |
| `url_launcher_platform_interface` | 2.3.2 | BSD-3-Clause | https://pub.dev/packages/url_launcher_platform_interface |
| `url_launcher_web` | 2.4.3 | BSD-3-Clause | https://pub.dev/packages/url_launcher_web |
| `url_launcher_windows` | 3.1.6 | BSD-3-Clause | https://pub.dev/packages/url_launcher_windows |
| `uuid` | 4.6.0 | MIT | https://pub.dev/packages/uuid |
| `vector_math` | 2.4.2 | BSD-3-Clause | https://pub.dev/packages/vector_math |
| `vm_service` | 15.3.0 | BSD-3-Clause | https://pub.dev/packages/vm_service |
| `wakelock_plus_platform_interface` | 1.7.0 | BSD-3-Clause | https://pub.dev/packages/wakelock_plus_platform_interface |
| `watcher` | 1.2.1 | BSD-3-Clause | https://pub.dev/packages/watcher |
| `web` | 1.1.1 | BSD-3-Clause | https://pub.dev/packages/web |
| `web_socket` | 1.0.1 | BSD-3-Clause | https://pub.dev/packages/web_socket |
| `web_socket_channel` | 3.0.3 | BSD-3-Clause | https://pub.dev/packages/web_socket_channel |
| `webkit_inspection_protocol` | 1.2.1 | BSD-3-Clause | https://pub.dev/packages/webkit_inspection_protocol |
| `win32` | 6.4.0 | BSD-3-Clause | https://pub.dev/packages/win32 |
| `xdg_directories` | 1.1.0 | BSD-3-Clause | https://pub.dev/packages/xdg_directories |
| `xml` | 7.0.1 | MIT | https://pub.dev/packages/xml |
| `yaml` | 3.1.4 | MIT | https://pub.dev/packages/yaml |
| `zmodem` | 0.0.6 | MIT | https://pub.dev/packages/zmodem |

## Needs a human

The generator could not place these, or placed them as something that is not plainly compatible with shipping inside an MIT app. Read each one; the conclusions reached so far are in [OPEN_SOURCE_READINESS.md](OPEN_SOURCE_READINESS.md) § *Third-party licences*.

- `dbus` 0.7.15 — MPL-2.0
- `nm` 0.5.0 — MPL-2.0

