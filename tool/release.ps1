<#
.SYNOPSIS
  Arma y publica un release de Ecos del Tiempo (o, con -Juego Travesia, de
  Ecos del Tiempo: Travesía) para Windows (instalador + auto-actualización).
  Ver docs/specs/distribution.md § "Dos juegos, un repo".

.DESCRIPTION
  1. (sin -DryRun) Verifica: rama main, árbol git limpio, al día con
     origin/main, `gh` autenticado y que el tag vX.Y.Z no exista.
  2. Escribe la versión en pubspec.yaml (`version: X.Y.Z+N`, N = build
     anterior + 1) y en lib/app/app_version.dart.
  3. flutter analyze + flutter test (salvo -SkipChecks).
  4. flutter build windows --release -t lib/app/flavors/main_p2p.dart
  5. Copia el runtime de MSVC (msvcp140, vcruntime140, vcruntime140_1) a
     dist\runtime y compila installer\ecos_del_tiempo.iss con Inno Setup 6.
  6. Escribe dist\EcosDelTiempo-Setup-X.Y.Z.exe.sha256.
  6b. Capturas: sube docs\release_shots\vX.Y.Z\*.png (novedades) y
     docs\release_shots\base\*.png (siempre) y las agrega al final de las
     notas, después de <!-- capturas --> (el juego no muestra esa parte).
  7. (sin -DryRun) Commit "chore(release): vX.Y.Z" del pubspec + versión,
     push a origin main y `gh release create vX.Y.Z <setup> <sha256>`.

  -Juego Travesia (por defecto Mundo, el flujo de arriba sin cambios):
  tag travesia-vX.Y.Z, versión en lib/app/travesia_version.dart (el
  pubspec no se toca), flavor lib/app/flavors/main_roguelike.dart,
  installer\ecos_travesia.iss -> dist\EcosDelTiempo-Travesia-Setup-X.Y.Z.exe,
  capturas de docs\release_shots\travesia-vX.Y.Z y travesia-base, y el
  release sale con --latest=false --prerelease (nunca es el "latest" del
  repo, que sigue siendo de Ecos del Tiempo).

.EXAMPLE
  .\tool\release.ps1 -Version 0.2.0 -Notes "Jefe nuevo y arreglos" -DryRun
  .\tool\release.ps1 -Version 0.2.0 -NotesFile notas.md
  .\tool\release.ps1 -Juego Travesia -Version 0.1.0 -Notes "Primera Travesía" -DryRun
#>
[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)]
  [string]$Version,
  [ValidateSet('Mundo', 'Travesia')]
  [string]$Juego = 'Mundo',
  [string]$Notes = '',
  [string]$NotesFile = '',
  [switch]$DryRun,
  [switch]$SkipChecks,
  [string]$FlutterBin = 'C:\tools\flutter\bin'
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
Set-Location $Root
$Utf8NoBom = New-Object System.Text.UTF8Encoding $false

function Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Fail($msg) { Write-Host "ERROR: $msg" -ForegroundColor Red; exit 1 }
function Run($exe, [string[]]$argv) {
  & $exe @argv
  if ($LASTEXITCODE -ne 0) { Fail "$exe $($argv -join ' ') salió con código $LASTEXITCODE" }
}

# --- Versión ---------------------------------------------------------------
$semver = '^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(-[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?$'
if ($Version.StartsWith('v')) { $Version = $Version.Substring(1) }
if ($Version -notmatch $semver) { Fail "Versión inválida '$Version' (formato X.Y.Z o X.Y.Z-pre.N)" }
$numeric = ($Version -split '-')[0]

# --- Juego (docs/specs/distribution.md § "Dos juegos, un repo") -----------
if ($Juego -eq 'Travesia') {
  $GameTitle = 'Ecos del Tiempo: Travesía'
  $TagPrefix = 'travesia-v'
  $Target = 'lib/app/flavors/main_roguelike.dart'
  $IssFile = 'installer\ecos_travesia.iss'
  $SetupPrefix = 'EcosDelTiempo-Travesia-Setup-'
  $VersionFile = 'lib/app/travesia_version.dart'
  $ShotsBase = 'docs\release_shots\travesia-base'
} else {
  $GameTitle = 'Ecos del Tiempo'
  $TagPrefix = 'v'
  $Target = 'lib/app/flavors/main_p2p.dart'
  $IssFile = 'installer\ecos_del_tiempo.iss'
  $SetupPrefix = 'EcosDelTiempo-Setup-'
  $VersionFile = 'lib/app/app_version.dart'
  $ShotsBase = 'docs\release_shots\base'
}
$Tag = "$TagPrefix$Version"
if ($NotesFile) { $Notes = [IO.File]::ReadAllText((Resolve-Path $NotesFile), [Text.Encoding]::UTF8) }
if (-not $Notes) { $Notes = "$GameTitle $Tag" }

$env:Path = "$FlutterBin;$env:Path"
$Flutter = Join-Path $FlutterBin 'flutter.bat'
if (-not (Test-Path $Flutter)) { Fail "No encuentro Flutter en $FlutterBin" }

# --- Chequeos de publicación ----------------------------------------------
if (-not $DryRun) {
  Step 'Verificando git y gh'
  $branch = (git rev-parse --abbrev-ref HEAD).Trim()
  if ($branch -ne 'main') { Fail "Hay que publicar desde main (estás en '$branch')." }
  $dirty = git status --porcelain
  if ($dirty) { Fail "El árbol git tiene cambios sin commitear:`n$($dirty -join "`n")" }
  Run git @('fetch', 'origin', 'main', '--tags')
  $head = (git rev-parse HEAD).Trim()
  $remote = (git rev-parse origin/main).Trim()
  if ($head -ne $remote) { Fail 'main local no coincide con origin/main (hacé pull/push primero).' }
  # En Windows PowerShell 5.1, con ErrorActionPreference = Stop, cualquier
  # línea de stderr de un comando nativo se vuelve error fatal (p. ej. el
  # "release not found" esperado de gh). Acá solo importa el exit code.
  $prevEap = $ErrorActionPreference
  $ErrorActionPreference = 'Continue'
  & gh auth status *> $null
  $authCode = $LASTEXITCODE
  & gh release view $Tag *> $null
  $viewCode = $LASTEXITCODE
  $ErrorActionPreference = $prevEap
  if ($authCode -ne 0) { Fail 'gh no está autenticado: corré "gh auth login".' }
  if ($viewCode -eq 0) { Fail "El release $Tag ya existe en GitHub." }
  if (git tag --list $Tag) { Fail "El tag $Tag ya existe." }
} else {
  Write-Host 'DRY RUN: se arma todo pero NO se commitea, pushea ni publica.' -ForegroundColor Yellow
}

# --- 1. Versión en pubspec y app_version.dart -----------------------------
Step "Versión $Version ($GameTitle)"
$pubspecPath = Join-Path $Root 'pubspec.yaml'
$pubspec = [IO.File]::ReadAllText($pubspecPath, [Text.Encoding]::UTF8)
$m = [regex]::Match($pubspec, '(?m)^version:[ \t]*([^\s+]+)(?:\+(\d+))?[ \t]*(?=\r?$)')
if (-not $m.Success) { Fail 'No encuentro la línea version: en pubspec.yaml' }
$oldVersion = $m.Groups[1].Value
$oldBuild = if ($m.Groups[2].Success) { [int]$m.Groups[2].Value } else { 0 }
if ($Juego -eq 'Travesia') {
  # Travesía tiene su propia versión: el pubspec (de Ecos del Tiempo) no se
  # toca; el build number del exe es el del pubspec tal cual.
  $build = [math]::Max($oldBuild, 1)
  $travesiaDart = @"
// GENERADO por tool/release.ps1 -Juego Travesia — no editar a mano.
// Versión propia de Ecos del Tiempo: Travesía (docs/specs/distribution.md
// § "Dos juegos, un repo"): no sigue al ``version:`` del pubspec, que es la
// de Ecos del Tiempo.

/// Versión instalada de Travesía (``X.Y.Z``), la del tag ``travesia-vX.Y.Z``.
const String travesiaVersion = '$Version';

"@
  [IO.File]::WriteAllText((Join-Path $Root 'lib\app\travesia_version.dart'), $travesiaDart.Replace("`r`n", "`n"), $Utf8NoBom)
  Write-Host "travesia_version.dart -> $Version (pubspec sin cambios: $oldVersion+$oldBuild)"
} else {
$build = if ($oldVersion -eq $Version) { [math]::Max($oldBuild, 1) } else { $oldBuild + 1 }
$pubspec = $pubspec.Substring(0, $m.Index) + "version: $Version+$build" +
  $pubspec.Substring($m.Index + $m.Length)
[IO.File]::WriteAllText($pubspecPath, $pubspec, $Utf8NoBom)
$versionDart = @"
// GENERADO por tool/release.ps1 — no editar a mano.
// Copia en código de la línea ``version:`` de pubspec.yaml (sin el ``+build``)
// para que el auto-actualizador sepa qué versión corre (docs/specs/distribution.md
// § "Versionado"). test/core/update/app_version_test.dart verifica que no
// se desincronice del pubspec.

/// Versión instalada (``X.Y.Z``), la misma que el tag ``vX.Y.Z`` del release.
const String appVersion = '$Version';

"@
[IO.File]::WriteAllText((Join-Path $Root 'lib\app\app_version.dart'), $versionDart.Replace("`r`n", "`n"), $Utf8NoBom)
Write-Host "pubspec: $oldVersion+$oldBuild -> $Version+$build"
}

# --- 2. Análisis y tests ---------------------------------------------------
if (-not $SkipChecks) {
  Step 'flutter analyze'
  Run $Flutter @('analyze')
  Step 'flutter test'
  Run $Flutter @('test')
}

# --- 3. Build release (flavor del juego) ----------------------------------
Step "flutter build windows --release ($Target)"
Run $Flutter @('build', 'windows', '--release', '-t', $Target,
  '--build-name', $Version, '--build-number', "$build")
$bundle = Join-Path $Root 'build\windows\x64\runner\Release'
if (-not (Test-Path (Join-Path $bundle 'echos_del_tiempo.exe'))) { Fail "No está el exe en $bundle" }

# --- 4. Runtime MSVC app-local --------------------------------------------
Step 'Runtime de MSVC (app-local)'
$dist = Join-Path $Root 'dist'
$runtime = Join-Path $dist 'runtime'
New-Item -ItemType Directory -Force $runtime | Out-Null
Get-ChildItem $runtime -Filter *.dll -ErrorAction SilentlyContinue | Remove-Item -Force
$crt = Get-ChildItem -Directory -ErrorAction SilentlyContinue -Path @(
  "${env:ProgramFiles(x86)}\Microsoft Visual Studio\*\*\VC\Redist\MSVC\*\x64\Microsoft.VC14*.CRT",
  "$env:ProgramFiles\Microsoft Visual Studio\*\*\VC\Redist\MSVC\*\x64\Microsoft.VC14*.CRT"
) | Sort-Object { [version]($_.Parent.Parent.Name -replace '[^\d.]', '') } -Descending | Select-Object -First 1
if (-not $crt) { Fail 'No encuentro el redist de MSVC (VS 2022 Build Tools, VC\Redist\MSVC\...\x64\Microsoft.VC143.CRT).' }
foreach ($dll in 'msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll') {
  Copy-Item (Join-Path $crt.FullName $dll) $runtime -Force
}
Write-Host "Desde $($crt.FullName)"

# --- 5. Instalador ---------------------------------------------------------
Step 'Inno Setup'
$iscc = @(
  "$env:LOCALAPPDATA\Programs\Inno Setup 6\ISCC.exe",
  "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
  "$env:ProgramFiles\Inno Setup 6\ISCC.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $iscc) { Fail 'No encuentro ISCC.exe (Inno Setup 6).' }
Run $iscc @('/Q', "/DAppVersion=$Version", "/DAppVersionNumeric=$numeric",
  "/DSourceDir=$bundle", "/DRuntimeDir=$runtime", "/DOutputDir=$dist",
  (Join-Path $Root $IssFile))
$setupName = "$SetupPrefix$Version.exe"
$setup = Join-Path $dist $setupName
if (-not (Test-Path $setup)) { Fail "ISCC no generó $setup" }

# --- 6. Checksum -----------------------------------------------------------
$hash = (Get-FileHash -Algorithm SHA256 $setup).Hash.ToLower()
$shaFile = "$setup.sha256"
[IO.File]::WriteAllText($shaFile, "$hash  $setupName`n", (New-Object System.Text.ASCIIEncoding))
$size = (Get-Item $setup).Length
Step 'Listo'
Write-Host ("Instalador: {0} ({1:N1} MB, {2:N0} bytes)" -f $setup, ($size / 1MB), $size)
Write-Host "SHA-256:    $hash"

if ($DryRun) {
  Write-Host "`nDRY RUN: no se publicó nada. Para publicar (desde main, árbol limpio):" -ForegroundColor Yellow
  Write-Host "  .\tool\release.ps1 -Juego $Juego -Version $Version -Notes `"...`""
  exit 0
}

# --- 7. Commit + push + release --------------------------------------------
Step "Publicando $Tag"
if ($Juego -eq 'Travesia') {
  Run git @('add', $VersionFile)
} else {
  Run git @('add', 'pubspec.yaml', $VersionFile)
}
& git diff --cached --quiet
if ($LASTEXITCODE -ne 0) {
  Run git @('commit', '-m', "chore(release): $Tag")
  Run git @('push', 'origin', 'main')
}
$prerelease = @()
if ($Version.Contains('-')) { $prerelease = @('--prerelease') }
# Travesía nunca es el "latest" del repo: el actualizador de Ecos del Tiempo
# usa releases/latest (docs/specs/distribution.md § "Dos juegos, un repo").
if ($Juego -eq 'Travesia') { $prerelease = @('--latest=false', '--prerelease') }
# Capturas (docs/specs/distribution.md § "Capturas en el release"): siempre
# las base (docs/release_shots/base) y, si hay, las nuevas de esta versión
# (docs/release_shots/vX.Y.Z). Se suben como archivos del release y se
# agregan al final de las notas, después de la marca que el juego recorta.
$shotAssets = @()
$shotMd = ''
$baseUrl = "https://github.com/KarmaBlank/echos-del-tiempo/releases/download/$Tag"
foreach ($sec in @(
    @{ Dir = "docs\release_shots\$Tag"; Prefix = 'nuevo'; Title = "### Novedades de $Tag" },
    @{ Dir = $ShotsBase; Prefix = 'juego'; Title = '### El juego' })) {
  $dir = Join-Path $Root $sec.Dir
  if (-not (Test-Path $dir)) { continue }
  $pngs = Get-ChildItem $dir -Filter *.png | Sort-Object Name
  if (-not $pngs) { continue }
  $shotMd += "`n$($sec.Title)`n`n"
  foreach ($p in $pngs) {
    $assetName = "$($sec.Prefix)-$($p.Name)"
    $copy = Join-Path $dist $assetName
    Copy-Item $p.FullName $copy -Force
    $shotAssets += $copy
    $label = ($p.BaseName -replace '^\d+[a-z]?_', '') -replace '_', ' '
    $shotMd += "![$label]($baseUrl/$assetName)`n"
  }
}
if ($shotMd) { $Notes = $Notes.TrimEnd() + "`n`n<!-- capturas -->`n## Capturas`n$shotMd" }
# Las notas van por archivo: PowerShell 5.1 rompe los argumentos con
# comillas dobles al pasarlos a un ejecutable (las notas las tienen).
$notesTmp = Join-Path ([IO.Path]::GetTempPath()) "ecos-release-notes-$Tag.md"
[IO.File]::WriteAllText($notesTmp, $Notes, (New-Object System.Text.UTF8Encoding($false)))
Run gh (@('release', 'create', $Tag, $setup, $shaFile) + $shotAssets + @(
  '--target', 'main', '--title', "$GameTitle $Tag", '--notes-file', $notesTmp) + $prerelease)
Remove-Item $notesTmp -ErrorAction SilentlyContinue
Write-Host "`nPublicado: https://github.com/KarmaBlank/echos-del-tiempo/releases/tag/$Tag" -ForegroundColor Green
