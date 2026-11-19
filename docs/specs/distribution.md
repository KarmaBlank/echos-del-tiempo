# Distribución: instalador y auto-actualización (Windows)

Cómo se le pasa el juego a los amigos y cómo se actualiza solo. Código:
`installer/ecos_del_tiempo.iss`, `tool/release.ps1`, `lib/core/update/`,
`lib/app/app_version.dart`. Tests: `test/core/update/`.

## Qué recibe un amigo

Un solo archivo `EcosDelTiempo-Setup-X.Y.Z.exe` (Inno Setup 6), bajado de
la página de Releases de GitHub
(<https://github.com/KarmaBlank/echos-del-tiempo/releases/latest>).

- **Sin admin**: instala por usuario en
  `%LOCALAPPDATA%\Programs\Ecos del Tiempo` (no pregunta carpeta).
- Interfaz en castellano, accesos directos en el menú Inicio y (casilla
  marcada por defecto) en el escritorio, desinstalador en
  "Aplicaciones instaladas".
- Lleva el bundle completo de `flutter build windows --release`
  (`echos_del_tiempo.exe`, `flutter_windows.dll`, plugins, `data\`) menos
  `*.lib/*.exp/*.pdb`, y el **runtime de MSVC app-local**
  (`msvcp140.dll`, `vcruntime140.dll`, `vcruntime140_1.dll`, copiados del
  redist de VS 2022 Build Tools): el `.exe` y los plugins
  (`audioplayers`, `flutter_webrtc`) los importan y una PC limpia puede no
  tener el "Visual C++ Redistributable". El UCRT (`api-ms-win-crt-*`) ya
  viene con Windows 10+ (`MinVersion=10.0`).
- `AppId` **fijo** (`{4C7488FB-DCDF-4DF1-B136-FAED0FDD2981}`): una versión
  nueva se instala encima de la anterior. No cambiarlo nunca.
- `[InstallDelete]` borra `{app}\data` antes de copiar: no quedan assets
  viejos entre versiones.
- Si el juego está abierto, el instalador lo cierra (Restart Manager,
  `CloseApplications=force`).

### Flavor que se distribuye

El release se compila con `lib/app/flavors/main_p2p.dart`: P2P por
internet (WebRTC, señalización por la API REST de Firestore en
escritorio; docs/specs/netcode.md). El composition root registra **un
solo** `NetSessionFactory` y la pantalla de título usa ese, así que el
release no ofrece LAN. Para jugar por LAN hay que compilar
`main_lan.dart` aparte. Ofrecer las dos en el mismo build pide cambiar el
contrato (lista de factories y selector en el título) — queda fuera de
este spec.

## Perfil guardado

El perfil vive en `%APPDATA%\EcosDelTiempo` (Roaming;
`JsonFileProfileStore.forPlatform`, docs/specs/exploration.md §
"Persistencia"), **fuera** de la carpeta de instalación (que está en
`%LOCALAPPDATA%`). Ni la actualización ni la desinstalación lo tocan
(`[UninstallDelete]` solo borra `{app}`). Desinstalar y reinstalar
conserva el personaje.

## Versionado

- Fuente de verdad: la línea `version: X.Y.Z+N` de `pubspec.yaml`.
- En tiempo de ejecución la versión sale de **`lib/app/app_version.dart`**
  (`const appVersion = 'X.Y.Z'`), archivo generado por `tool/release.ps1`
  y commiteado. Se eligió esto (y no `--dart-define`) para que también
  `flutter run` y los tests vean la versión real sin flags, sin sumar
  dependencias (`package_info_plus`). `test/core/update/app_version_test.dart`
  falla si el archivo y el pubspec se desincronizan.
- Tag del release: `vX.Y.Z` (SemVer 2.0; se admite `vX.Y.Z-pre.N`, que
  se publica como *prerelease* y por eso **no** lo ve el actualizador:
  `/releases/latest` ignora prereleases).
- `N` (build number) sube solo en cada release; Windows lo usa en el
  recurso de versión del `.exe`.
- Comparación (`SemVer` en `lib/core/update/semver.dart`): numérica por
  partes; `1.0.0-rc.1 < 1.0.0`; `+build` se ignora; tags basura
  (`latest`, `1.2`, `v1.2.x`) no son actualizaciones.

## Flujo de actualización

`UpdateBanner` (`lib/core/update/presentation/`) va montado en la pantalla
de título.

1. **Buscar**: al abrir el juego (solo builds release; en desarrollo con
   el botón `BUSCAR`) → `GET
   https://api.github.com/repos/KarmaBlank/echos-del-tiempo/releases/latest`
   sin token, `User-Agent: EcosDelTiempo-Updater`, timeout 8 s.
   - Tag mayor que `appVersion` y con instalador → panel dorado
     **"Actualización disponible vX.Y.Z"** con las notas del release y
     `ACTUALIZAR`.
   - Igual o menor → `vX.Y.Z · al día`. 404 (sin releases) → "Todavía no
     hay versiones publicadas."
   - Sin internet, timeout, 5xx, JSON raro, límite de GitHub (403/429,
     muestra la hora de `x-ratelimit-reset`) → una línea gris con el
     motivo y `REINTENTAR`. **Nunca bloquea el juego.**
2. **Elegir assets**: instalador = asset `EcosDelTiempo-Setup-*.exe`
   (prefiere el que nombra la versión del tag), checksum =
   `<instalador>.sha256`. Solo URLs `https`.
3. **Descargar** a `%TEMP%\EcosDelTiempo-update\` (`.part` mientras baja)
   con barra de progreso; corta si pasan 30 s sin datos.
4. **Verificar**: tamaño exacto al `size` de la API y **SHA-256** igual
   al del `.sha256` (calculado en Dart puro mientras baja). Un release sin
   `.sha256` se rechaza. Si algo no coincide se borra el archivo y se
   muestra el error con `REINTENTAR`.
5. **Instalar**: lanza el instalador (proceso independiente) con
   `/VERYSILENT /SUPPRESSMSGBOXES /NORESTART /CLOSEAPPLICATIONS /RELAUNCH
   /LOG=%TEMP%\EcosDelTiempo-update\install.log` y el juego se cierra
   (`exit(0)`). `/RELAUNCH` es un parámetro propio del `.iss`: en modo
   silencioso abre `echos_del_tiempo.exe` al terminar.

Fuera de Windows `ACTUALIZAR` queda deshabilitado ("Solo en Windows").

## Publicar un release (dueño)

Requisitos: Flutter en `C:\tools\flutter\bin`, VS 2022 Build Tools (redist
MSVC), Inno Setup 6, `gh` autenticado (`gh auth login`).

```powershell
git checkout main; git pull
.\tool\release.ps1 -Version 0.2.0 -Notes "Jefe nuevo y arreglos" -DryRun   # prueba
.\tool\release.ps1 -Version 0.2.0 -Notes "Jefe nuevo y arreglos"           # publica
```

El script: verifica rama `main`, árbol limpio, al día con `origin/main`,
`gh` autenticado y tag inexistente (solo sin `-DryRun`); escribe la
versión en `pubspec.yaml` y `app_version.dart`; corre `flutter analyze` y
`flutter test` (`-SkipChecks` los saltea); compila el flavor P2P; copia
el runtime MSVC a `dist\runtime`; compila el instalador a
`dist\EcosDelTiempo-Setup-X.Y.Z.exe`; escribe `…exe.sha256` (formato
`sha256sum`). Sin `-DryRun` además commitea `chore(release): vX.Y.Z`,
hace push a `origin main` y corre `gh release create vX.Y.Z <setup>
<setup>.sha256 --target main --title … --notes …`. `-NotesFile` toma las
notas de un archivo. `dist/` está en `.gitignore`.

**Parches de balance**: el admin (`lib/app/flavors/main_admin.dart`,
docs/specs/balance_admin.md) escribe `assets/balance/balance.json` y
`docs/patch_notes/vX.Y.Z.md` y muestra los pasos (rama → PR → merge →
`release.ps1 -Version X.Y.Z -NotesFile docs\patch_notes\vX.Y.Z.md`).
Cada parche de balance es un release PATCH nuevo: el hash de balance va
en el `hello` y una sala no mezcla parches distintos.

## Capturas en el release

Pedido del dueño: cada release muestra capturas del juego, siempre unas
base y además las nuevas de los cambios.

- `docs/release_shots/base/*.png`: las capturas base (1920×1080), que van
  en **todos** los releases. Se reemplazan cuando el juego cambia mucho
  de aspecto.
- `docs/release_shots/vX.Y.Z/*.png`: las de los cambios de esa versión
  (opcional). Se sacan del juego compilado antes de publicar.
- El orden es el del nombre (`01_…`, `02_…`); el texto del nombre, sin el
  número, es la descripción de la imagen.
- `release.ps1` las sube como archivos del release (`nuevo-…` y
  `juego-…`) y agrega al final de las notas:
  `<!-- capturas -->`, `## Capturas`, `### Novedades de vX.Y.Z` y
  `### El juego`, con las imágenes.
- El juego no muestra imágenes: `ReleaseInfo.stripScreenshots` corta las
  notas en `<!-- capturas -->`, así el cartel de actualización muestra
  solo el texto. (Los clientes anteriores a esta versión sí ven las
  líneas de imagen al final de las notas.)

## Seguridad

- **Sin firma de código**: Windows SmartScreen muestra "Windows protegió
  su PC" la primera vez. El amigo tiene que tocar **"Más información" →
  "Ejecutar de todos modos"**. Las actualizaciones automáticas no pasan
  por SmartScreen (el `.exe` lo baja el juego, sin la marca de
  "descargado de internet"). Firmar el instalador (certificado de código)
  lo eliminaría — pendiente si algún día hace falta.
- **Checksum**: el SHA-256 detecta descargas corruptas o truncadas y
  assets cambiados a mano sin actualizar el `.sha256`. No protege contra
  alguien que controle la cuenta de GitHub (subiría ambos); para eso haría
  falta firma. Todo va por HTTPS a `api.github.com` / CDN de GitHub.
- **Límite de la API**: sin token, GitHub permite 60 consultas por hora
  por IP. El juego consulta una vez por arranque (o por botón), así que
  solo se nota con muchos jugadores detrás de la misma IP; en ese caso el
  banner lo dice y el juego sigue normal.
- El updater solo instala lo que publica `KarmaBlank/echos-del-tiempo`
  (URL fija en `GitHubUpdateService.defaultEndpoint`).

## Qué tienen que hacer los amigos

1. Abrir la página de Releases y bajar `EcosDelTiempo-Setup-X.Y.Z.exe`.
2. Ejecutarlo; si aparece SmartScreen: "Más información" → "Ejecutar de
   todos modos". Siguiente → Instalar (no pide admin).
3. Para jugar juntos por internet: uno crea la sala y pasa el código.
4. Actualizaciones: al abrir el juego, si hay versión nueva aparece el
   aviso en la pantalla de título → `ACTUALIZAR`. El juego se cierra, se
   instala solo y se vuelve a abrir. El personaje se conserva.
5. Desinstalar: Configuración → Aplicaciones → "Ecos del Tiempo" (el
   perfil queda en `%APPDATA%\EcosDelTiempo`; borrarlo a mano si se
   quiere empezar de cero).
