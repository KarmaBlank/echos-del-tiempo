/// Plan de publicación de un parche de balance (docs/specs/balance_admin.md
/// § 5, pestaña Parche). Dart puro: solo arma textos y comandos; quien los
/// corre es el dueño (o el botón del admin, con confirmación).
class ReleasePlan {
  const ReleasePlan(this.version);

  /// `X.Y.Z` (sin la `v`).
  final String version;

  static const balancePath = 'assets/balance/balance.json';

  /// Worktree de publicación de `tool/release.ps1` (docs/specs/distribution.md).
  static const releaseWorktree =
      r'C:\Users\joses\Documents\Desarrollos\echos-release';

  String get tag => 'v$version';
  String get branch => 'balance/$tag';
  String get notesPath => 'docs/patch_notes/$tag.md';
  String get notesPathWindows => notesPath.replaceAll('/', r'\');

  /// La versión `X.Y.Z` de la línea `version:` de un pubspec.
  static String? pubspecVersion(String pubspec) => RegExp(
          r'^version:[ \t]*(\d+\.\d+\.\d+)', multiLine: true)
      .firstMatch(pubspec)
      ?.group(1);

  /// La siguiente versión: PATCH +1 (por defecto) o MINOR +1.
  static String next(String current, {bool minor = false}) {
    final m = RegExp(r'^(\d+)\.(\d+)\.(\d+)').firstMatch(current);
    if (m == null) return '0.0.1';
    final major = int.parse(m.group(1)!);
    final mi = int.parse(m.group(2)!);
    final pa = int.parse(m.group(3)!);
    return minor ? '$major.${mi + 1}.0' : '$major.$mi.${pa + 1}';
  }

  static bool isValid(String v) => RegExp(r'^\d+\.\d+\.\d+$').hasMatch(v);

  /// Argumentos de `tool/release.ps1` (para `powershell -File`).
  List<String> scriptArgs({required bool dryRun}) => [
        '-NoProfile',
        '-ExecutionPolicy',
        'Bypass',
        '-File',
        r'.\tool\release.ps1',
        '-Version',
        version,
        '-NotesFile',
        notesPathWindows,
        if (dryRun) '-DryRun',
      ];

  /// Los pasos, en orden, con sus comandos exactos.
  List<ReleaseStep> steps() => [
        ReleaseStep(
          'Revisar y commitear en una rama (repo de trabajo)',
          'Revisá el diff de $balancePath y las notas antes de commitear.',
          [
            'git checkout -b $branch',
            'git add $balancePath $notesPath',
            'git commit -m "balance: parche $tag"',
            'git push -u origin $branch',
          ],
        ),
        ReleaseStep(
          'Pull request y merge a main',
          'CI tiene que pasar (analyze + test). También se puede hacer desde GitHub.',
          [
            'gh pr create --base main --head $branch --title "Balance $tag" '
                '--body-file $notesPath',
            'gh pr merge --squash --delete-branch',
          ],
        ),
        ReleaseStep(
          'Publicar el release (worktree $releaseWorktree)',
          'release.ps1 solo publica desde un main limpio y al día: sube '
              'pubspec + app_version.dart, corre analyze/test/build, arma el '
              'instalador y hace gh release create. Probá primero con -DryRun.',
          [
            'cd $releaseWorktree',
            'git checkout main',
            'git pull --ff-only',
            r'.\tool\release.ps1 -Version '
                '$version -NotesFile $notesPathWindows -DryRun',
            r'.\tool\release.ps1 -Version '
                '$version -NotesFile $notesPathWindows',
          ],
        ),
      ];
}

/// Un paso del plan, con sus comandos copiables.
class ReleaseStep {
  const ReleaseStep(this.title, this.detail, this.commands);
  final String title;
  final String detail;
  final List<String> commands;
}
