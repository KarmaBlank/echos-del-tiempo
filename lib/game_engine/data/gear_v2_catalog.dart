// Profession gear v2 (docs/specs/profession_gear_v2.md): affinity of the
// existing materials, fish parts and the forge-by-parts steps. Pure data;
// every number lives in `kTuning[TuningId.gearV2]`. Nothing new is
// invented here: ingots, biome rares, fish, composts and elements all
// exist already.

import '../models/elements.dart';

/// Every weapon type the forge by parts can make (§ 3).
const kForgeWeaponTypes = [
  'espada',
  'hacha',
  'lanza',
  'dagas',
  'arco',
  'ballesta',
  'rifle',
  'báculo',
  'varita',
  'tomo',
  'espada+escudo',
  'maza+escudo',
  'martillo+escudo',
];

/// Types a living weapon can grow into (§ 5): all but the rifle.
List<String> get kLivingWeaponTypes =>
    [for (final t in kForgeWeaponTypes) if (t != 'rifle') t];

/// Ingot (forge base / head / grip) → affinity (§ 1).
const kIngotAffinity = <String, GameElement>{
  'ingot_copper': GameElement.fisico,
  'ingot_bronze': GameElement.electro,
  'ingot_frost': GameElement.hielo,
  'ingot_ember': GameElement.fuego,
  'ingot_echo': GameElement.sagrado,
};

/// Biome rare material (optional setting) → affinity (§ 1).
const kRareAffinity = <String, GameElement>{
  'rare_amber': GameElement.veneno,
  'rare_cog': GameElement.electro,
  'rare_rime': GameElement.hielo,
  'rare_magma': GameElement.fuego,
  'rare_sand': GameElement.sagrado,
};

/// Elemental compost → affinity of a living weapon (§ 5). Plain compost
/// (`abono`) leaves it physical.
const kCompostAffinity = <String, GameElement>{
  'abono_brasa': GameElement.fuego,
  'abono_escarcha': GameElement.hielo,
  'abono_runico': GameElement.electro,
  'abono_eco': GameElement.sagrado,
  'abono_miel': GameElement.veneno,
};

/// One step of the forge by parts (§ 3).
enum PartSlot { base, head, grip, setting }

/// A piece Brann takes out of a fish (§ 4).
enum FishPart { scale, bone, essence }

/// Smithing material id of a fish part (`fp_<species>_<part>`).
String fishPartId(String species, FishPart part) =>
    'fp_${species}_${part.name}';

final _fishPart = RegExp(r'^fp_(.+)_(scale|bone|essence)$');

/// (species, part) of a fish part id, or `null`.
(String, FishPart)? parseFishPart(String id) {
  final m = _fishPart.firstMatch(id);
  if (m == null) return null;
  return (m.group(1)!, FishPart.values.byName(m.group(2)!));
}

/// Affinity of a fish species, by its theme (§ 1): cold → ice, fire →
/// fire, clockwork / runes → electro, light / bells / echoes → holy,
/// anything else → water.
GameElement fishAffinity(String species) {
  bool has(List<String> ws) => ws.any(species.contains);
  if (has(['escarcha', 'invierno', 'hielo', 'nev', 'frio'])) {
    return GameElement.hielo;
  }
  if (has(['fuego', 'brasa', 'forja', 'rescoldo', 'igneo'])) {
    return GameElement.fuego;
  }
  if (has(['reloj', 'engranaje', 'runic', 'runa'])) {
    return GameElement.electro;
  }
  if (has(['luz', 'campana', 'eco', 'eras', 'archivo'])) {
    return GameElement.sagrado;
  }
  return GameElement.agua;
}

/// Gear id prefix of a weapon forged by parts (`parts_<typeKey>`).
const kPartsGearPrefix = 'parts_';
