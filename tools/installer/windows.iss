; Windows per-user setup. The release script supplies all four definitions.
#ifndef GameVersion
  #error GameVersion is required, for example /DGameVersion=0.4.1.5
#endif
#ifndef BuildDir
  #error BuildDir is required and must contain the exported game and licenses
#endif
#ifndef OutputDir
  #error OutputDir is required
#endif
#ifndef GameExe
  #define GameExe "Niente Zombie Per Favore.exe"
#endif
#define AppName "Niente Zombie Per Favore!"

[Setup]
; Do not change AppId between versions: upgrades reuse the installation.
AppId={{DA98E75B-CECC-42D2-8726-89AD42A54FA3}
AppName={#AppName}
AppVersion={#GameVersion}
AppVerName={#AppName} {#GameVersion}
VersionInfoVersion={#GameVersion}
VersionInfoProductName={#AppName}
VersionInfoProductVersion={#GameVersion}
VersionInfoDescription=Installazione di {#AppName}
DefaultDirName={localappdata}\Programs\Niente Zombie Per Favore
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
AllowNoIcons=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
OutputDir={#OutputDir}
OutputBaseFilename=Niente-Zombie-Per-Favore-Setup-{#GameVersion}
Compression=lzma2/normal
SolidCompression=yes
WizardStyle=modern
UninstallDisplayIcon={app}\{#GameExe}
UninstallDisplayName={#AppName}
CloseApplications=yes
RestartApplications=no
SetupLogging=yes
#ifdef InstallerSmokeTest
; Used only by the isolated install/uninstall test, never by release builds.
CreateUninstallRegKey=no
#endif

[Languages]
Name: "italian"; MessagesFile: "compiler:Languages\Italian.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#BuildDir}\{#GameExe}"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#BuildDir}\*.pck"; DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist
Source: "{#BuildDir}\*.dll"; DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist
Source: "{#BuildDir}\*.txt"; DestDir: "{app}\Licenze"; Flags: ignoreversion skipifsourcedoesntexist
Source: "{#BuildDir}\*.md"; DestDir: "{app}\Licenze"; Flags: ignoreversion skipifsourcedoesntexist
Source: "{#BuildDir}\Licenze\*"; DestDir: "{app}\Licenze"; Flags: ignoreversion recursesubdirs createallsubdirs skipifsourcedoesntexist

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\{#GameExe}"; WorkingDir: "{app}"; Check: not WizardNoIcons
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#GameExe}"; WorkingDir: "{app}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#GameExe}"; WorkingDir: "{app}"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent
; In-game updates run the setup with /SILENT: relaunch the upgraded game.
Filename: "{app}\{#GameExe}"; WorkingDir: "{app}"; Flags: nowait skipifnotsilent

; No AppData deletion: Godot save games and preferences survive upgrades and
; uninstallation. Inno removes only files registered by this installer.
