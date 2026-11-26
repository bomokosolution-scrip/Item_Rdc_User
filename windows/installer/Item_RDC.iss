; Script Inno Setup (https://jrsoftware.org/isinfo.php)
; 1) flutter build windows --release
; 2) Ouvrez ce fichier avec Inno Setup, puis "Build > Compile"
; => crée  windows\installer\Output\Item_RDC_Setup.exe  (installateur unique)

#define AppName "Item RDC"
#define AppVersion "1.0.0"
#define AppPublisher "Bomoko Solution"
#define AppExe "item_rdc.exe"
#define BuildDir "..\..\build\windows\x64\runner\Release"

[Setup]
AppId={{6B1F2C9A-4D3E-4A57-9B8E-2F7A1C5D0E11}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL=mailto:bomokosolution@gmail.com
DefaultDirName={autopf}\Item RDC
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
OutputDir=Output
OutputBaseFilename=Item_RDC_Setup
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#AppExe}
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog

[Languages]
Name: "french"; MessagesFile: "compiler:Languages\French.isl"

[Tasks]
Name: "desktopicon"; Description: "Créer un raccourci sur le Bureau"; GroupDescription: "Raccourcis :"

[Files]
Source: "{#BuildDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\{#AppExe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExe}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExe}"; Description: "Lancer {#AppName}"; Flags: nowait postinstall skipifsilent
