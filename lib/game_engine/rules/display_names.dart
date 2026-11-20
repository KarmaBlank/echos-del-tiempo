import '../data/affixes_catalog.dart';
import '../data/ascension_catalog.dart';
import '../data/ascension_mechanics.dart';
import '../data/branch_ults_catalog.dart';
import '../data/elemental_skills_catalog.dart';
import '../data/elements_catalog.dart';
import '../data/enemies_catalog.dart';
import '../data/passive_mechanics.dart';
import '../data/passive_tree_catalog.dart';
import '../data/skill_variants_catalog.dart';
import '../data/skills_catalog.dart';
import '../data/summoner_catalog.dart';
import '../data/uniques_catalog.dart';
import '../data/ults_v2_catalog.dart';
import '../data/weapon_passives.dart';
import '../models/status.dart';

// Nombre legible (en español) de cualquier fuente de un proc, efecto o
// nota de batalla: mecánica del árbol, pasiva de arma (`wp:<id>:<nivel>`),
// mod, nodo, ULT (de camino, v2, ascensión, invocador), legendario,
// estado o reacción. Único punto de resolución: nunca devuelve el id.

final Map<String, String> _cache = {};

/// Nombre legible de [id]. Si no está en ningún catálogo, uno derivado
/// del id (sin prefijos, guiones bajos ni números de nivel).
String displayName(String id) =>
    _cache.putIfAbsent(id, () => _lookup(id) ?? humanizeId(id));

String? _lookup(String id) {
  final direct = _named(id);
  if (direct != null) return direct;
  // `wp:<pasiva>:<nivel>#n`, `mod:<afijo>`, `node:<id>`, `ult:<id>`...
  final head = id.split('#').first;
  if (head.contains(':')) {
    for (final part in head.split(':').reversed) {
      if (part.isEmpty || int.tryParse(part) != null) continue;
      final n = _named(part);
      if (n != null) return n;
    }
  }
  return null;
}

String? _named(String id) =>
    mechanicById(id)?.name ??
    kWeaponPassives[id]?.name ??
    kAscensionMechanics[id]?.name ??
    kSkills[id]?.name ??
    kAllUltimates[id]?.name ??
    kBranchUltSkills[id]?.name ??
    kUltV2[id]?.skill.name ??
    kWeaponUltSkills[id]?.name ??
    kAscensionSkills[id]?.name ??
    kAscensionUltimatesById[id]?.name ??
    kElementalSkills[id]?.name ??
    kSkillVariants[id]?.name ??
    kSummonerSkills[id]?.name ??
    kSummonerUltimates[id]?.name ??
    kBossMechanics[id]?.name ??
    kEliteUlts[id]?.name ??
    kEnemyUlts[id]?.name ??
    kUniques[id]?.name ??
    kAffixes[id]?.name ??
    kPassiveTree.nodes[id]?.name ??
    kReactions[id]?.kind.label ??
    kElementStatuses[id]?.kind.label ??
    _enumLabel(id) ??
    _special[id];

String? _enumLabel(String id) {
  for (final s in StatusKind.values) {
    if (s.name == id) return s.label;
  }
  for (final r in ReactionKind.values) {
    if (r.name == id) return r.label;
  }
  return null;
}

/// Fuentes sin catálogo propio que emite el motor.
const Map<String, String> _special = {
  'vigilancia': 'Vigilante del Vacío',
  'escudo': 'Escudo',
};

/// Derivado legible de un id: `wp:filoResonante:3` → «Filo Resonante»,
/// `ult2_loQueSera` → «Lo Que Sera».
String humanizeId(String id) {
  final parts = [
    for (final p in id.split('#').first.split(RegExp(r'[:_\-\s]+')))
      if (p.isNotEmpty &&
          int.tryParse(p) == null &&
          !_prefixes.contains(p.toLowerCase()))
        p,
  ];
  final words = [
    for (final p in parts)
      for (final w in p
          .replaceAllMapped(
              RegExp(r'([a-záéíóúñ])([A-ZÁÉÍÓÚÑ0-9])'), (m) => '${m[1]} ${m[2]}')
          .split(' '))
        if (w.isNotEmpty) w,
  ];
  if (words.isEmpty) return 'Efecto';
  return [
    for (final w in words) w[0].toUpperCase() + w.substring(1),
  ].join(' ');
}

const Set<String> _prefixes = {
  'wp', 'mod', 'node', 'ult', 'ult2', 'ult1', 'sk', 'mech', 'proc', 'v6', 'v7',
};
