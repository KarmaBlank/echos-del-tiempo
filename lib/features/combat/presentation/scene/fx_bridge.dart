import 'dart:math' as math;

import 'package:flutter/services.dart' show AssetBundle;

import '../../../../core/fx/fx_catalog.dart';
import '../../../../game_engine/data/branch_ults_catalog.dart' show kBranchUltLooks;
import '../../../../game_engine/data/enemies_catalog.dart' show kEnemyUlts;
import '../../../../game_engine/fx/cinematic_durations.dart';
import 'duo_cinematic.dart';
import 'fx_style.dart' show kSkillsById;
import 'ult_cinematic.dart';

/// Puente entre los datos FXA (docs/specs/game_editor.md § 2) y la
/// tubería de cinemáticas de la escena (`UltScript`).

/// Arma un `FxTimeline` equivalente para cada cinemática que todavía es
/// código (§ 2.3): fases, cámara, oscurecido, impactos, hit-stop y
/// sacudida salen del `UltScript`; el dibujo queda en una pista `legacy`
/// (`style`) que sigue pintando `UltDirector`.
class LegacyFxAdapter implements LegacyFxSource {
  const LegacyFxAdapter();

  static final _cache = <String, FxTimeline?>{};

  @override
  Iterable<String> get ids =>
      [...kUltScripts.keys, ...kEnemyUltScripts.keys, 'duo'];

  @override
  FxTimeline? build(String id) => _cache.putIfAbsent(id, () {
        final s = id == 'duo'
            ? kDuoScript
            : kUltScripts[id] ?? kEnemyUltScripts[id];
        if (s == null) return null;
        final category = id == 'duo'
            ? 'duo'
            : kEnemyUltScripts.containsKey(id)
                ? 'enemy_ult'
                : 'ult';
        final name = id == 'duo'
            ? 'Dúo (código)'
            : kSkillsById[id]?.name ?? kEnemyUlts[id]?.name ?? id;
        return fromScript(id, s, category: category, name: name);
      });

  /// El timeline de [s] (público para el test de oro de tiempos).
  static FxTimeline fromScript(String id, UltScript s,
      {String category = 'ult', String? name}) {
    final focus = switch (s.focus) {
      UltFocus.single => 'target',
      UltFocus.line => 'line',
      UltFocus.party => 'allies',
      UltFocus.targets => 'targets',
      UltFocus.group => 'group',
    };
    return FxTimeline(
      id: id,
      category: category,
      name: name,
      tags: [s.style.name, 'legacy'],
      duration: s.totalMs,
      phases: FxPhases(s.buildMs, s.releaseMs, s.returnMs),
      targets: switch (s.focus) {
        UltFocus.single => 'single',
        UltFocus.line => 'line',
        UltFocus.party => 'allies',
        _ => 'all',
      },
      legacy: true,
      tracks: [
        FxTrack('camera', keys: [
          FxKey(0, {'focus': 'caster'}),
          FxKey(s.buildMs, {'focus': focus}),
        ]),
        FxTrack('dim', keys: [
          FxKey(0, {'v': 0}),
          FxKey(200, {'v': 0.85}),
          FxKey(s.buildMs, {'v': 0.85}),
          FxKey(s.buildMs + 200, {'v': 0.62}),
          FxKey(s.returnAt, {'v': 0.62}),
          FxKey(s.totalMs, {'v': 0}),
        ]),
        FxTrack('impact', fires: [
          for (final t in s.preHitsMs) FxKey(t, {'pre': true}),
          FxKey(s.impactMs, {'stagger': s.staggerMs}),
        ]),
        if (s.hitStopMs > 0)
          FxTrack('hitstop',
              fires: [FxKey(s.impactMs, {'ms': s.hitStopMs})]),
        FxTrack('shake', fires: [FxKey(s.impactMs, {'amp': s.shake})]),
        FxTrack('legacy', props: {'style': s.style.name}),
      ],
    );
  }
}

/// Guion de escena desde una animación de datos: las fases, el primer
/// impacto (con su `stagger`), los golpes previos, el hit-stop y la
/// sacudida mayores, y el foco de la cámara en la descarga. [style] es el
/// del código (sonido y elemento de partículas por defecto).
UltScript scriptFromTimeline(FxTimeline t, UltStyle style) {
  final imp = t.impacts;
  final first = imp.isEmpty ? null : imp.first;
  var hit = 0, amp = 0.0;
  for (final f in t.track('hitstop')?.fires ?? const <FxKey>[]) {
    hit = math.max(hit, f.n('ms')?.toInt() ?? 0);
  }
  for (final tr in t.ofType('shake')) {
    for (final f in tr.fires) {
      amp = math.max(amp, f.d('amp', 0));
    }
  }
  final build = t.phases.build;
  final release = math.max(0, math.min(t.phases.release, t.duration - build));
  final focus = switch (t.track('camera')?.textAt('focus', build + 1.0)) {
    'target' => UltFocus.single,
    'line' => UltFocus.line,
    'allies' => UltFocus.party,
    'group' => UltFocus.group,
    _ => UltFocus.targets,
  };
  return UltScript(
    style: style,
    buildMs: build,
    releaseMs: release,
    returnMs: math.max(0, t.duration - build - release),
    impactMs: first?.t ?? build,
    staggerMs: first?.n('stagger')?.toInt() ?? 0,
    preHitsMs: t.preHits,
    hitStopMs: hit,
    shake: amp,
    focus: focus,
    data: t,
  );
}

final _derived = Expando<UltScript>('fxScript');

UltScript _scriptOf(FxTimeline t, UltStyle style) =>
    _derived[t] ??= scriptFromTimeline(t, style);

/// El guion de datos de la ULT [id] (o de la ULT a la que se parece, si
/// es de camino), o `null` si no hay catálogo o solo hay legacy.
UltScript? dataScriptFor(String? id, UltScript code) {
  final cat = FxCatalog.active;
  if (cat == null || id == null) return null;
  var t = cat.timeline(id);
  if (t == null || t.legacy) {
    final look = kBranchUltLooks[id];
    t = look == null ? null : cat.timeline(look);
  }
  if (t == null || t.legacy) return null;
  return _scriptOf(t, code.style);
}

/// El guion de datos del dúo [key] (`duo_<key>` → `duo`), o `null`.
UltScript? dataDuoScript(String? key) {
  final t = FxCatalog.active?.forAction('duo', key);
  if (t == null || t.legacy) return null;
  return _scriptOf(t, UltStyle.duo);
}

/// Carga el catálogo de fx del juego y lo deja activo: la escena lo usa
/// para las cinemáticas y el motor para la espera de fin de batalla (con
/// las duraciones del release, nunca las de un override; § 4.3).
Future<FxCatalog> installFx(
    {AssetBundle? bundle, FxOverrideSource? overrides}) async {
  final cat = await FxCatalog.load(
      bundle: bundle, overrides: overrides, legacy: const LegacyFxAdapter());
  FxCatalog.active = cat;
  final d = cat.releaseDurations().ms;
  CinematicDurations.shared = CinematicDurations({
    // ULT de camino: la duración de la ULT a la que se parece.
    for (final MapEntry(:key, :value) in kBranchUltLooks.entries)
      if (d[value] case final ms?) key: ms,
    ...d,
  });
  return cat;
}
