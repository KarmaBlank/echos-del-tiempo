import '../../../game_engine/data/ascension_catalog.dart';
import '../../../game_engine/data/trials_catalog.dart';
import '../../../game_engine/models/ascension.dart';
import '../../../game_engine/models/player_profile.dart';
import '../../../game_engine/rules/ascension_rules.dart';

/// Textos de la ascensión (docs/specs/ascension.md). Dart puro.

/// La ascensión [id] si es de la clase [classId].
AscensionDef? ascensionFor(String? classId, String? id) {
  final a = kAscensions[id];
  return a != null && a.classId == classId ? a : null;
}

/// `Ana, Cronomante` (o solo el nombre si no ascendió). § 5.
String heroTitle(String name, String? classId, String? ascensionId) {
  final a = ascensionFor(classId, ascensionId);
  return a == null ? name : '$name, ${a.name}';
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

/// `Pruebas I II · 4/6 puntos` para fichas cortas.
String trialsSummary(AscensionProgress a) {
  final done = [
    for (final t in kTrials)
      if (a.trials.contains(t.number)) t.roman
  ];
  return done.isEmpty
      ? 'Sin Pruebas'
      : 'Pruebas ${done.join(' ')} · ${const AscensionRules().free(a)} '
          'punto${const AscensionRules().free(a) == 1 ? '' : 's'} libre'
          '${const AscensionRules().free(a) == 1 ? '' : 's'}';
}

/// Línea del resultado de una Prueba: lo que ganó el jugador local.
String trialResultText(int n, bool gained) {
  final t = trialDef(n);
  final name = t == null ? 'Prueba' : 'Prueba ${t.roman}';
  return gained
      ? '¡$name superada! +${AscensionProgress.pointsPerTrial} puntos de '
          'ascensión'
      : '$name superada (ya la tenías o no cumplís el nivel: sin puntos)';
}

/// Aviso de la Prueba superada (§ 1.2).
String trialCompletedText(String name, int n) =>
    '$name superó la ${trialDef(n)?.fullName ?? 'Prueba'}: '
    '+${AscensionProgress.pointsPerTrial} puntos de ascensión';
