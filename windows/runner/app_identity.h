#ifndef RUNNER_APP_IDENTITY_H_
#define RUNNER_APP_IDENTITY_H_

// Which app this exe is. Included by Runner.rc and main.cpp, so the version
// resource and the window title cannot disagree.
//
// SSHETU_DEBUG_IDENTITY is defined for the Debug configuration only (see
// runner/CMakeLists.txt). A debug build is its own app, "SSHetu Debug":
// path_provider, shared_preferences and flutter_secure_storage_windows all
// build their folder from the exe's CompanyName and ProductName
// (%APPDATA%\PopupBits\<ProductName>), so a different ProductName is a
// different folder, and a debug build never opens the real install's settings
// or credentials. lib/core/config/app_config.dart (AppIdentity) checks for
// that folder at startup and refuses to run without it.
//
// The release value is the folder every existing install's data is in.
// Changing it strands that data.
#ifdef SSHETU_DEBUG_IDENTITY
#define SSHETU_PRODUCT_NAME "SSHetu Debug"
#define SSHETU_WINDOW_TITLE L"SSHetu Debug"
#else
#define SSHETU_PRODUCT_NAME "SSHetu"
#define SSHETU_WINDOW_TITLE L"SSHetu"
#endif

#endif  // RUNNER_APP_IDENTITY_H_
