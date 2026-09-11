#define MyAppName "Dixit Motors ERP"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Dixit Motors"
#define MyAppExeName "dixit_motors_management_app.exe"

[Setup]
AppId={{DIXIT-MOTORS-ERP-2026}}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\Dixit Motors ERP
DefaultGroupName={#MyAppName}

OutputDir=installer_output
OutputBaseFilename=Dixit_Motors_ERP_Setup

Compression=lzma
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin
ArchitecturesInstallIn64BitMode=x64
DisableProgramGroupPage=yes

SetupIconFile=windows\runner\resources\app_icon.ico

UninstallDisplayIcon={app}\{#MyAppExeName}

[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\Dixit Motors ERP"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\Dixit Motors ERP"; Filename: "{app}\{#MyAppExeName}"

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Launch Dixit Motors ERP"; Flags: nowait postinstall skipifsilent