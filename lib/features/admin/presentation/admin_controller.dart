import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/update/release_channel.dart';
import '../../../core/update/semver.dart';
import '../../../game_engine/balance/balance_codecs.dart';
import '../../../game_engine/balance/balance_patch.dart';
import '../../../game_engine/balance/balance_registries.dart';
import '../../../game_engine/data/game_catalog.dart';
import '../data/monitoring_clients.dart';
import '../domain/admin_host.dart';
import '../domain/admin_index.dart';
import '../domain/balance_diff.dart';
import '../domain/monitoring.dart';
import '../domain/release_plan.dart';

/// Estado del admin (docs/specs/balance_admin.md § 5): borrador de
/// balance, archivo guardado, selección, parche y monitoreo.
class AdminController extends ChangeNotifier {
  AdminController({
    required this.host,
    this.firestoreProjectId = '',
    this.firestoreApiKey = '',
    BalanceBase? base,
  }) : base = base ?? BalanceBase.standard() {
    index = buildAdminIndex(this.base);
    repoPath = host.defaultRepoPath;
  }

  final AdminHost host;
  final BalanceBase base;
  final String firestoreProjectId;
  final String firestoreApiKey;
  late final List<AdminEntry> index;

  // ------------------------------------------------------------------
  // Repo y archivo
  // ------------------------------------------------------------------

  String? repoPath;
  String? fileStatus;

  /// `balance.json` del repo tal como está en disco.
  BalancePatch saved = BalancePatch.empty;
  List<BalanceIssue> savedIssues = const [];

  /// Lo que se está editando (puede tener valores inválidos).
  BalancePatch draft = BalancePatch.empty;

  /// [draft] validado: lo que se aplicaría.
  BalancePatch validDraft = BalancePatch.empty;
  List<BalanceIssue> draftIssues = const [];

  /// Versión del `pubspec.yaml` del repo.
  String? currentVersion;

  bool get hasRepo => repoPath != null && host.supportsFiles;
  bool get dirty => draft.hash != saved.hash || draftIssues.any((i) => i.error);
  bool get canSave => hasRepo && !draftIssues.any((i) => i.error);

  String _path(String rel) => host.join(repoPath!, rel);

  Future<void> load() async {
    if (!hasRepo) {
      fileStatus = host.supportsFiles
          ? 'No encontré el repo: abrí el admin desde la carpeta del proyecto '
              'o pasá --dart-define=ECOS_REPO=<ruta>.'
          : 'Sin disco (web): se puede editar y previsualizar, no guardar.';
      notifyListeners();
      return;
    }
    try {
      final text = await host.readFile(_path(ReleasePlan.balancePath));
      final r = BalancePatch.parse(text ?? '', base);
      saved = r.patch;
      savedIssues = r.issues;
      draft = r.patch;
      final pub = await host.readFile(_path('pubspec.yaml'));
      currentVersion = pub == null ? null : ReleasePlan.pubspecVersion(pub);
      await _loadReleased();
      fileStatus = text == null
          ? 'No existe ${ReleasePlan.balancePath}: se creará al guardar.'
          : 'Leído ${ReleasePlan.balancePath} (${saved.entityCount} entradas).';
    } on Object catch (e) {
      fileStatus = 'Error leyendo el repo: $e';
    }
    _revalidate();
    _resetNotes();
    notifyListeners();
  }

  Future<void> setRepoPath(String path) async {
    repoPath = path.trim().isEmpty ? null : path.trim();
    await load();
  }

  /// `balance.json` de `main` (lo publicado): base de las notas de parche.
  BalancePatch released = BalancePatch.empty;
  String releasedSource = 'el código (sin balance.json publicado)';

  /// Lee `main:assets/balance/balance.json` con `git show` (solo lectura).
  Future<void> _loadReleased() async {
    if (!host.supportsProcesses) return;
    final out = <String>[];
    try {
      final code = await host.run(
          'git', ['show', 'main:${ReleasePlan.balancePath}'],
          workingDirectory: repoPath!, onLine: out.add);
      if (code == 0) {
        released = BalancePatch.parse(
                out.where((l) => !l.startsWith('[stderr]')).join('\n'), base)
            .patch;
        releasedSource = 'main (${released.entityCount} entradas publicadas)';
      }
    } on Object {
      // sin git: las notas comparan contra el código
    }
  }

  void _revalidate() {
    final r = BalancePatch.fromJson(draft.toJson(), base);
    validDraft = r.patch;
    draftIssues = r.issues;
    _catalogCache.clear();
  }

  /// Guarda el borrador en `assets/balance/balance.json`.
  Future<bool> save() async {
    if (!canSave) return false;
    final toWrite = validDraft.withBasedOn(currentVersion ?? validDraft.basedOn);
    try {
      await host.writeFile(_path(ReleasePlan.balancePath), toWrite.toPrettyJson());
      saved = toWrite;
      draft = toWrite;
      savedIssues = const [];
      fileStatus = 'Guardado ${ReleasePlan.balancePath} '
          '(${saved.entityCount} entradas, hash ${saved.hash}).';
      _revalidate();
      notifyListeners();
      return true;
    } on Object catch (e) {
      fileStatus = 'No se pudo guardar: $e';
      notifyListeners();
      return false;
    }
  }

  // ------------------------------------------------------------------
  // Navegador y edición
  // ------------------------------------------------------------------

  String query = '';
  String? category;
  AdminEntry? selected;

  List<AdminEntry> get visible => [
        for (final e in index)
          if ((category == null || e.category == category) && e.matches(query)) e,
      ];

  void setQuery(String q) {
    query = q;
    notifyListeners();
  }

  void setCategory(String? c) {
    category = c;
    notifyListeners();
  }

  void select(AdminEntry e) {
    selected = e;
    notifyListeners();
  }

  void selectRef(BalanceKind kind, String id) {
    for (final e in index) {
      if (e.kind == kind && e.id == id) {
        select(e);
        return;
      }
    }
  }

  /// Valores del código / del archivo / del borrador de una entidad.
  Map<String, Object?> baseFields(BalanceKind k, String id) =>
      codecOf(k).read(base.entities(k)[id]!);
  Map<String, Object?> savedFields(BalanceKind k, String id) =>
      saved.effectiveFields(base, k, id);
  Map<String, Object?> draftFields(BalanceKind k, String id) =>
      draft.effectiveFields(base, k, id);

  bool isTouched(BalanceKind k, String id) =>
      draft.fieldsOf(k, id).isNotEmpty || saved.fieldsOf(k, id).isNotEmpty;

  void setField(BalanceKind k, String id, String key, Object? value) {
    draft = draft.withField(k, id, key, value,
        baseValue: baseFields(k, id)[key]);
    _revalidate();
    notifyListeners();
  }

  /// Vuelve un campo al valor guardado en `balance.json`.
  void revertField(BalanceKind k, String id, String key) =>
      setField(k, id, key, savedFields(k, id)[key]);

  /// Vuelve una entidad al código (borra sus overrides del borrador).
  void resetEntity(BalanceKind k, String id) {
    draft = draft.withoutEntity(k, id);
    _revalidate();
    notifyListeners();
  }

  void discardAll() {
    draft = saved;
    _revalidate();
    notifyListeners();
  }

  /// Errores y avisos de una entidad.
  List<BalanceIssue> issuesOf(BalanceKind k, String id) => [
        for (final i in draftIssues)
          if (i.path == '${k.jsonKey}.$id' || i.path.startsWith('${k.jsonKey}.$id.'))
            i,
      ];

  /// Cambios pendientes (guardado → borrador).
  List<BalanceChange> get pendingChanges => diffBalance(base, saved, validDraft);

  /// Cambios del parche respecto de lo publicado en `main`.
  List<BalanceChange> get patchChanges => diffBalance(base, released, validDraft);

  // ------------------------------------------------------------------
  // Catálogos para la vista previa
  // ------------------------------------------------------------------

  final _catalogCache = <String, GameCatalog>{};

  GameCatalog get savedCatalog =>
      _catalogCache.putIfAbsent('saved', () => saved.applyTo(GameCatalog.standard));
  GameCatalog get draftCatalog =>
      _catalogCache.putIfAbsent('draft', () => validDraft.applyTo(GameCatalog.standard));

  /// Corre [f] con los registros globales del archivo guardado y después
  /// con los del borrador (afijos, nodos, mecánicas).
  (T, T) beforeAfter<T>(T Function(GameCatalog catalog) f) {
    BalanceRegistries.install(saved.overrides);
    final a = f(savedCatalog);
    BalanceRegistries.install(validDraft.overrides);
    final b = f(draftCatalog);
    return (a, b);
  }

  int previewLevel = 10;
  String previewEnemy = 'golem';
  String previewClass = 'guerrero';
  int previewEnemyCount = 1;

  void setPreview({int? level, String? enemy, String? classId, int? count}) {
    if (level != null) previewLevel = level.clamp(1, 60);
    if (enemy != null) previewEnemy = enemy;
    if (classId != null) previewClass = classId;
    if (count != null) previewEnemyCount = count.clamp(1, 4);
    notifyListeners();
  }

  // ------------------------------------------------------------------
  // Parche
  // ------------------------------------------------------------------

  bool minorBump = false;
  String notes = '';
  bool notesEdited = false;
  String? patchStatus;

  /// La versión más alta publicada en GitHub (si ya se consultó) de Ecos
  /// del Tiempo: solo tags `vX.Y.Z`. Los `travesia-vX.Y.Z` son del otro
  /// juego del repo y tienen su propia numeración (docs/specs/
  /// distribution.md § "Dos juegos, un repo").
  String? get latestReleased => latestReleasedOf(ReleaseChannel.mundo);

  /// La más alta de [channel] (prereleases fuera).
  String? latestReleasedOf(ReleaseChannel channel) {
    SemVer? best;
    for (final r in releases ?? const <GithubRelease>[]) {
      final v = channel.versionOf(r.tag);
      if (r.draft || v == null || v.isPrerelease) continue;
      if (best == null || v.compareTo(best) > 0) best = v;
    }
    return best == null ? null : '${best.major}.${best.minor}.${best.patch}';
  }

  /// La versión de partida: la mayor entre el pubspec del repo y lo ya
  /// publicado (otro release pudo salir desde otra rama).
  String get baseVersion {
    final pub = SemVer.tryParse(currentVersion);
    final gh = SemVer.tryParse(latestReleased);
    if (pub == null) return latestReleased ?? '0.0.0';
    if (gh == null) return currentVersion!;
    return gh.compareTo(pub) > 0 ? latestReleased! : currentVersion!;
  }

  String get nextVersion {
    var v = ReleasePlan.next(baseVersion, minor: minorBump);
    // Nunca repetir un tag ya publicado (de cualquiera de los dos juegos).
    while (tagTaken(ReleaseChannel.mundo.tagFor(v))) {
      v = ReleasePlan.next(v);
    }
    return v;
  }

  /// Si [tag] ya existe entre los releases consultados.
  bool tagTaken(String tag) =>
      (releases ?? const <GithubRelease>[]).any((r) => r.tag == tag);
  ReleasePlan get plan => ReleasePlan(nextVersion);

  void setMinor(bool v) {
    minorBump = v;
    if (!notesEdited) _resetNotes();
    notifyListeners();
  }

  void regenerateNotes() {
    _resetNotes();
    notifyListeners();
  }

  void _resetNotes() {
    notes = buildPatchNotes(version: nextVersion, changes: patchChanges);
    notesEdited = false;
  }

  void editNotes(String text) {
    notes = text;
    notesEdited = true;
  }

  /// Escribe `balance.json` y `docs/patch_notes/vX.Y.Z.md`.
  Future<bool> writePatchFiles() async {
    if (!canSave) {
      patchStatus = hasRepo
          ? 'Hay errores de validación: corregilos antes.'
          : 'Sin repo: no se puede escribir.';
      notifyListeners();
      return false;
    }
    if (!await save()) return false;
    try {
      await host.writeFile(_path(plan.notesPath), notes.endsWith('\n') ? notes : '$notes\n');
      patchStatus = 'Escritos ${ReleasePlan.balancePath} y ${plan.notesPath}.';
      notifyListeners();
      return true;
    } on Object catch (e) {
      patchStatus = 'No se pudieron escribir las notas: $e';
      notifyListeners();
      return false;
    }
  }

  // ---- release.ps1 con salida en vivo (siempre tras confirmación) ----

  final releaseLog = <String>[];
  bool releaseRunning = false;
  int? releaseExit;

  /// Corre `tool/release.ps1` en el worktree de publicación. La UI solo
  /// lo llama después del diálogo de confirmación que nombra la versión.
  Future<void> runRelease({required String confirmedVersion, required bool dryRun}) async {
    if (releaseRunning || !host.supportsProcesses) return;
    if (confirmedVersion != nextVersion) return; // la confirmación no coincide
    releaseRunning = true;
    releaseExit = null;
    releaseLog
      ..clear()
      ..add('> powershell ${plan.scriptArgs(dryRun: dryRun).join(' ')}')
      ..add('  (en ${ReleasePlan.releaseWorktree})');
    notifyListeners();
    try {
      releaseExit = await host.run(
        'powershell',
        plan.scriptArgs(dryRun: dryRun),
        workingDirectory: ReleasePlan.releaseWorktree,
        onLine: (l) {
          releaseLog.add(l);
          notifyListeners();
        },
      );
    } on Object catch (e) {
      releaseLog.add('ERROR: $e');
      releaseExit = -1;
    }
    releaseRunning = false;
    notifyListeners();
  }

  // ------------------------------------------------------------------
  // Monitoreo
  // ------------------------------------------------------------------

  List<GithubRelease>? releases;
  String? releasesError;
  bool releasesLoading = false;

  Future<void> refreshReleases() async {
    releasesLoading = true;
    releasesError = null;
    notifyListeners();
    try {
      releases = await GithubReleasesClient(host).fetch();
      // La versión siguiente puede cambiar (otro release ya salió).
      if (!notesEdited) _resetNotes();
    } on Object catch (e) {
      releasesError = '$e';
    }
    releasesLoading = false;
    notifyListeners();
  }

  FirestoreMonitor? get _firestore => firestoreProjectId.isEmpty
      ? null
      : FirestoreMonitor(host,
          projectId: firestoreProjectId, apiKey: firestoreApiKey);

  RoomCount? roomCount;
  RoomInfo? roomInfo;
  String? roomError;
  bool roomsLoading = false;

  Future<void> countRooms() async {
    final f = _firestore;
    if (f == null) {
      roomCount = const RoomCount.failed('Firebase sin configurar');
      notifyListeners();
      return;
    }
    roomsLoading = true;
    notifyListeners();
    roomCount = await f.countRooms();
    roomsLoading = false;
    notifyListeners();
  }

  Future<void> lookupRoom(String code) async {
    final f = _firestore;
    if (f == null || code.trim().isEmpty) return;
    roomsLoading = true;
    roomError = null;
    notifyListeners();
    try {
      roomInfo = await f.room(code);
    } on Object catch (e) {
      roomInfo = null;
      roomError = '$e';
    }
    roomsLoading = false;
    notifyListeners();
  }

  List<LogLine> logLines = const [];
  String? logStatus;
  String logFilter = '';
  bool logErrorsOnly = false;

  Future<void> loadLog() async {
    final path = host.gameLogPath;
    if (path == null || !host.supportsFiles) {
      logStatus = 'Sin acceso al log en esta plataforma.';
      notifyListeners();
      return;
    }
    try {
      final old = await host.readFile('$path.1') ?? '';
      final cur = await host.readFile(path);
      if (cur == null && old.isEmpty) {
        logStatus = 'No hay $path todavía.';
        logLines = const [];
      } else {
        logLines = LogLine.parseAll('$old\n${cur ?? ''}');
        logStatus = '$path · ${logLines.length} líneas (solo lectura)';
      }
    } on Object catch (e) {
      logStatus = 'No se pudo leer el log: $e';
    }
    notifyListeners();
  }

  void setLogFilter({String? text, bool? errorsOnly}) {
    if (text != null) logFilter = text;
    if (errorsOnly != null) logErrorsOnly = errorsOnly;
    notifyListeners();
  }

  List<LogLine> get visibleLog => [
        for (final l in logLines.reversed)
          if ((!logErrorsOnly || l.level == 'ERROR') &&
              (logFilter.isEmpty ||
                  l.raw.toLowerCase().contains(logFilter.toLowerCase())))
            l,
      ];

  @override
  void dispose() {
    BalanceRegistries.restore();
    super.dispose();
  }
}
