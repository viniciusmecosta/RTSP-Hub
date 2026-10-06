#ifndef AppVersion
#define AppVersion "1.0.0"
#endif

[Setup]
AppId={{2B5542C7-8A4D-4A4D-9808-52CA24710EC8}
AppName=RTSP View
AppVersion={#AppVersion}
AppPublisher=RTSP View
DefaultDirName={autopf}\RTSP View
DefaultGroupName=RTSP View
OutputDir=dist
OutputBaseFilename=RTSP-View-Setup-{#AppVersion}-x64
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=lowest
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
UninstallDisplayIcon={app}\rtsp_view.exe

[Tasks]
Name: "desktopicon"; Description: "Criar atalho na área de trabalho"; GroupDescription: "Atalhos:"; Flags: unchecked
Name: "startup"; Description: "Iniciar automaticamente com o Windows"; GroupDescription: "Inicialização:"; Flags: unchecked

[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion

[Icons]
Name: "{group}\RTSP View"; Filename: "{app}\rtsp_view.exe"
Name: "{autodesktop}\RTSP View"; Filename: "{app}\rtsp_view.exe"; Tasks: desktopicon

[Registry]
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "RTSP View"; ValueData: """{app}\rtsp_view.exe"""; Tasks: startup; Flags: uninsdeletevalue

[Run]
Filename: "{app}\rtsp_view.exe"; Description: "Abrir RTSP View"; Flags: postinstall nowait skipifsilent
