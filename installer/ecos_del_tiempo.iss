; Instalador de Ecos del Tiempo (Inno Setup 6). Ver docs/specs/distribution.md.
;
; Lo compila tool/release.ps1:
;   ISCC.exe /DAppVersion=0.2.0 /DSourceDir=<bundle Release> /DRuntimeDir=<DLLs MSVC>
;            /DOutputDir=<dist> installer\ecos_del_tiempo.iss
;
; - Instalación por usuario, sin admin: %LOCALAPPDATA%\Programs\Ecos del Tiempo.
; - AppId FIJO: no cambiarlo nunca, es lo que hace que una versión nueva
;   se instale encima de la anterior (actualización en el lugar).
; - El perfil guardado vive en %APPDATA%\EcosDelTiempo (fuera de {app}):
;   ni la actualización ni la desinstalación lo tocan.
; - Parámetro propio /RELAUNCH: en modo silencioso, abre el juego al
;   terminar (lo usa el auto-actualizador).

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif
#ifndef AppVersionNumeric
  #define AppVersionNumeric AppVersion
#endif
#ifndef SourceDir
  #define SourceDir "..\build\windows\x64\runner\Release"
#endif
#ifndef RuntimeDir
  #define RuntimeDir "..\dist\runtime"
#endif
#ifndef OutputDir
  #define OutputDir "..\dist"
#endif

#define AppName "Ecos del Tiempo"
#define AppExe "echos_del_tiempo.exe"

[Setup]
AppId={{4C7488FB-DCDF-4DF1-B136-FAED0FDD2981}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher=KarmaBlank
AppPublisherURL=https://github.com/KarmaBlank/echos-del-tiempo
AppUpdatesURL=https://github.com/KarmaBlank/echos-del-tiempo/releases
VersionInfoVersion={#AppVersionNumeric}
VersionInfoProductName={#AppName}
PrivilegesRequired=lowest
DefaultDirName={localappdata}\Programs\{#AppName}
DisableDirPage=yes
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
UsePreviousAppDir=yes
OutputDir={#OutputDir}
OutputBaseFilename=EcosDelTiempo-Setup-{#AppVersion}
SetupIconFile=..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#AppExe}
UninstallDisplayName={#AppName}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
; Cierra el juego si está abierto (Restart Manager) — también en /VERYSILENT
; con /CLOSEAPPLICATIONS. No lo reabre el RM: lo hace [Run] con /RELAUNCH.
CloseApplications=force
CloseApplicationsFilter=*.exe,*.dll
RestartApplications=no

[Languages]
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[InstallDelete]
; Una actualización reemplaza el bundle entero: sin restos de la versión
; anterior (assets renombrados, plugins que ya no están).
Type: filesandordirs; Name: "{app}\data"

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Excludes: "*.lib,*.exp,*.pdb,*.ilk"; Flags: ignoreversion recursesubdirs createallsubdirs
; Runtime de MSVC app-local (msvcp140, vcruntime140, vcruntime140_1): el
; .exe y los plugins lo importan y no todas las PCs tienen el redist.
Source: "{#RuntimeDir}\*.dll"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\{#AppExe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExe}"; Tasks: desktopicon

[Run]
; Instalación con ventana: casilla "Ejecutar Ecos del Tiempo".
Filename: "{app}\{#AppExe}"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent
; Actualización silenciosa pedida por el juego: lo vuelve a abrir.
Filename: "{app}\{#AppExe}"; Flags: nowait; Check: ShouldRelaunch

[UninstallDelete]
Type: filesandordirs; Name: "{app}"

[Code]
function HasParam(const Name: String): Boolean;
var
  I: Integer;
begin
  Result := False;
  for I := 1 to ParamCount do
    if CompareText(ParamStr(I), Name) = 0 then
    begin
      Result := True;
      Exit;
    end;
end;

function ShouldRelaunch(): Boolean;
begin
  Result := WizardSilent() and HasParam('/RELAUNCH');
end;

