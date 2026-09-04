; Inno Setup script for the SSHetu desktop app (Windows installer).
;
; Build locally with tool\make_installer.ps1, or by hand:
;   flutter build windows --release
;   & "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe" /DMyAppVersion=1.0.0 windows\installer\sshetu.iss
;
; Output goes to windows/installer/output/SSHetu-Setup-<version>.exe.

#define MyAppName "SSHetu"
#define MyAppPublisher "PopupBits"
#define MyAppURL "https://github.com/popupbits/sshetu"
#define MyAppExeName "sshetu.exe"

#ifndef MyAppVersion
  #define MyAppVersion "0.0.0"
#endif

; Folder holding the `flutter build windows --release` output (the .exe, the
; DLLs and the data/ bundle). Overridable from the command line for CI.
#ifndef SourceDir
  #define SourceDir "..\..\build\windows\x64\runner\Release"
#endif

[Setup]
; A fixed AppId keeps upgrades and uninstall stable across versions. Never
; change it: a new one makes the next release install *beside* this one
; rather than over it, and leaves the old entry in Add/Remove Programs.
AppId={{7BE1A751-843F-463C-A12A-E8DD30D8B5DF}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}/issues
AppUpdatesURL={#MyAppURL}/releases
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
UninstallDisplayIcon={app}\{#MyAppExeName}
OutputDir=output
OutputBaseFilename=SSHetu-Setup-{#MyAppVersion}
SetupIconFile=..\runner\resources\app_icon.ico
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\Uninstall {#MyAppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
; --- The other device --------------------------------------------------------
; "Send to a device" opens a listening socket, so Windows Defender prompts the
; first time — and the prompt is the one thing the feature cannot survive:
; decline it and the QR code stays on screen with nothing able to reach the
; machine, which reads as the phone being at fault. The app cannot add this
; rule itself; only an installer runs with the rights to.
;
; Program-scoped rather than port-scoped, because the transfer listener takes
; whatever port it is given, and LocalSubnet-scoped because the whole design
; is two devices on the same network — nothing beyond it should reach in.
; Deleted first so reinstalling leaves one rule rather than a pile.
Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall delete rule name=""SSHetu"""; Flags: runhidden waituntilterminated
Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall add rule name=""SSHetu"" dir=in action=allow program=""{app}\{#MyAppExeName}"" enable=yes profile=private,domain protocol=tcp remoteip=LocalSubnet"; Flags: runhidden waituntilterminated; StatusMsg: "Allowing another device to reach SSHetu on this network..."

Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

[UninstallRun]
; A rule naming an executable that no longer exists is exactly the litter an
; uninstall is for.
Filename: "{sys}\netsh.exe"; Parameters: "advfirewall firewall delete rule name=""SSHetu"""; Flags: runhidden
