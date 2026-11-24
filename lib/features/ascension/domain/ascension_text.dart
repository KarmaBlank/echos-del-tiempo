import '../../../core/i18n/catalog_names.dart';
import '../../../core/i18n/game_text.dart';
import '../../../game_engine/data/ascension_catalog.dart';
import '../../../game_engine/data/trials_catalog.dart';
import '../../../game_engine/models/ascension.dart';
import '../../../game_engine/models/player_profile.dart';
import '../../../game_engine/rules/ascension_rules.dart';
import '../../endgame/domain/endgame_names.dart';

/// Textos de la ascensión (docs/specs/ascension.md) en el idioma activo
/// (`GameText`, docs/specs/i18n.md § 3.5). Dart puro.

/// La ascensión [id] si es de la clase [classId].
AscensionDef? ascensionFor(String? classId, String? id) {
  final a = kAscensions[id];
  return a != null && a.classId == classId ? a : null;
}

/// `Ana, Cronomante` (o solo el nombre si no ascendió). § 5.
String heroTitle(String name, String? classId, String? ascensionId) {
  final a = ascensionFor(classId, ascensionId);
  return a == null ? name : '$name, ${a.tr}';
}

/// El título de un perfil.
String profileTitle(PlayerProfile p) =>
    heroTitle(p.name, p.classId, p.ascension.id);

/// `#rrggbb` del color de una ascensión.
String ascensionHex(AscensionDef a) =>
    '#${(a.color & 0xFFFFFF).toRadixString(16).padLeft(6, '0')}';

/// Id del sprite para dibujar al héroe: `<clase>_<ascensión>` si ascendió
/// (quien dibuja cae al de la clase si no existe).
String heroSpriteId(String? classId, String? ascensionId) {
  final a = ascensionFor(classId, ascensionId);
  return a?.spriteId ?? classId ?? '';
}

/// `Pruebas I II · 4 puntos libres` para fichas cortas.
String trialsSummary(AscensionProgress a) {
  final done = [
    for (final t in kTrials)
      if (a.trials.contains(t.number)) t.roman
  ];
  return done.isEmpty
      ? GameText.t('ui.ascension.trials.none')
      : GameText.t('ui.ascension.trials.summary',
          {'list': done.join(' '), 'free': const AscensionRules().free(a)});
}

/// Línea del resultado de una Prueba: lo que ganó el jugador local.
String trialResultText(int n, bool gained) {
  final t = trialDef(n);
  final name = t == null
      ? GameText.t('ui.ascension.trial.generic')
      : GameText.t('ui.ascension.trial.short', {'roman': t.roman});
  return gained
      ? GameText.t('ui.ascension.trial.result_points',
          {'name': name, 'points': AscensionProgress.pointsPerTrial})
      : GameText.t('ui.ascension.trial.result_none', {'name': name});
}

/// Aviso de la Prueba superada (§ 1.2).
String trialCompletedText(String name, int n) =>
    GameText.t('ui.ascension.trial.completed', {
      'name': name,
      'trial': trialDef(n)?.fullNameTr ?? GameText.t('ui.ascension.trial.generic'),
      'points': AscensionProgress.pointsPerTrial,
    });

/// Por qué [p] no puede proponer la Prueba [n] (o `null`): espejo de
/// `TrialRules.cannotPropose` en el idioma activo.
String? trialProposeBlocked(PlayerProfile p, int n) {
  final t = trialDef(n);
  if (t == null) return GameText.t('ui.ascension.trial.unknown');
  if (p.level < t.level) {
    return GameText.t('ui.ascension.trial.requires_level', {'level': t.level});
  }
  if (n > 1 && !p.ascension.trials.contains(n - 1)) {
    return GameText.t(
        'ui.ascension.trial.requires_previous', {'roman': trialDef(n - 1)!.roman});
  }
  return null;
}
