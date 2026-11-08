; Installeur Windows d'ElioTV (Inno Setup 6) : produit un seul fichier ElioTV-Setup.exe.
; Compilé par GitHub Actions après `flutter build windows` (voir .github/workflows/build.yml).
; Installation pour l'utilisateur courant : aucun droit administrateur demandé.

#define AppName "ElioTV"
#ifndef AppVersion
  #define AppVersion "1.0.2"
#endif
#define BuildDir "..\..\build\windows\x64\runner\Release"

[Setup]
AppId={{8F3C2A51-6B7D-4E2A-9C14-5E0B7A9D3F62}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher=ElioTV
AppPublisherURL=https://nanousuport-svg.github.io/ElioTV/
AppSupportURL=https://github.com/nanousuport-svg/ElioTV
DefaultDirName={localappdata}\Programs\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
OutputDir=..\..\build\installer
OutputBaseFilename=ElioTV-Setup
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\eliotv.exe
UninstallDisplayName={#AppName}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
CloseApplications=yes

[Languages]
Name: "fr"; MessagesFile: "compiler:Languages\French.isl"
Name: "en"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "{#BuildDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\{#AppName}"; Filename: "{app}\eliotv.exe"
Name: "{group}\{cm:UninstallProgram,{#AppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\eliotv.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\eliotv.exe"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent
