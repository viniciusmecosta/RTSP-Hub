#ifndef AppVersion
#define AppVersion "1.0.0"
#endif

[Setup]
AppId={{2B5542C7-8A4D-4A4D-9808-52CA24710EC8}
AppName=RTSP Hub
AppVersion={#AppVersion}
AppPublisher=RTSP Hub
DefaultDirName={autopf}\RTSP Hub
DefaultGroupName=RTSP Hub
OutputDir=..\dist
OutputBaseFilename=RTSP-Hub-Setup-{#AppVersion}-x64
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=lowest
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
SetupIconFile=..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\rtsp_hub.exe

[Tasks]
Name: "desktopicon"; Description: "Criar atalho na área de trabalho"; GroupDescription: "Atalhos:"; Flags: unchecked
Name: "startup"; Description: "Iniciar automaticamente com o Windows"; GroupDescription: "Inicialização:"; Flags: unchecked

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion

[Icons]
Name: "{group}\RTSP Hub"; Filename: "{app}\rtsp_hub.exe"
Name: "{autodesktop}\RTSP Hub"; Filename: "{app}\rtsp_hub.exe"; Tasks: desktopicon

[Registry]
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "RTSP Hub"; ValueData: """{app}\rtsp_hub.exe"""; Tasks: startup; Flags: uninsdeletevalue

[Run]
Filename: "{app}\rtsp_hub.exe"; Description: "Abrir RTSP Hub"; Flags: postinstall nowait skipifsilent
