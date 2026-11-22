; Instalador de Ecos del Tiempo: Travesía (Inno Setup 6), el segundo juego
; del repo. Ver docs/specs/distribution.md § "Dos juegos, un repo".
;
; Lo compila tool/release.ps1:
;   ISCC.exe /DAppVersion=0.2.0 /DSourceDir=<bundle Release> /DRuntimeDir=<DLLs MSVC>
;            /DOutputDir=<dist> installer\ecos_travesia.iss
;   (tool\release.ps1 -Juego Travesia)
;
; - Instalación por usuario, sin admin: %LOCALAPPDATA%\Programs\Ecos del Tiempo Travesia.
;   Otra carpeta, otro AppId, otros accesos y otra entrada de desinstalación
;   que installer\ecos_del_tiempo.iss: los dos juegos conviven instalados.
; - AppId FIJO, propio de Travesía: NO CAMBIARLO NUNCA (es lo que hace que
;   una versión nueva se instale encima de la anterior) y nunca igualarlo
;   al de ecos_del_tiempo.iss (pisaría al otro juego).
; - El perfil guardado vive en %APPDATA%\EcosDelTiempo-Travesia (fuera de {app}):
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

#define AppName "Ecos del Tiempo: Travesía"
; Sin ":" (no vale en rutas de Windows).
#define AppDirName "Ecos del Tiempo Travesia"
#define AppExe "echos_del_tiempo.exe"

[Setup]
AppId={{BD419CB8-AA4F-41B8-95A1-89B11543044E}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher=KarmaBlank
AppPublisherURL=https://github.com/KarmaBlank/echos-del-tiempo
AppUpdatesURL=https://github.com/KarmaBlank/echos-del-tiempo/releases
VersionInfoVersion={#AppVersionNumeric}
VersionInfoProductName={#AppName}
PrivilegesRequired=lowest
DefaultDirName={localappdata}\Programs\{#AppDirName}
DisableDirPage=yes
DefaultGroupName={#AppDirName}
DisableProgramGroupPage=yes
UsePreviousAppDir=yes
OutputDir={#OutputDir}
OutputBaseFilename=EcosDelTiempo-Travesia-Setup-{#AppVersion}
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
Name: "{autoprograms}\{#AppDirName}"; Filename: "{app}\{#AppExe}"
Name: "{autodesktop}\{#AppDirName}"; Filename: "{app}\{#AppExe}"; Tasks: desktopicon

[Run]
; Instalación con ventana: casilla "Ejecutar Ecos del Tiempo: Travesía".
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

