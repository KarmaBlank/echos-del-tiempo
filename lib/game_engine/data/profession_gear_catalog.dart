// Profession gear (docs/specs/profession_gear.md): the weapons only a
// profession makes — living wood from the farm, sunken echo weapons and
// fish-forged weapons from fishing, forge-only weapons from smithing.
// Pure data; every number lives in `kTuning[TuningId.gear]`.

import '../models/item.dart' show UniqueMod;
import 'life_tree_catalog.dart' show LifeSkillKind;

/// Where a profession weapon comes from (profession_gear.md § 2).
enum GearSource {
  /// Grown from a weapon seed in a farm plot (Cultivo).
  living,

  /// Pulled up from deep water or a sunken chest (Pesca).
  sunken,

  /// Forged by Brann from a legendary fish (Pesca).
  fishForge,

  /// Forged at the town forge (Herrería).
  forge;

  LifeSkillKind get profession => switch (this) {
        GearSource.living => LifeSkillKind.cultivo,
        GearSource.sunken || GearSource.fishForge => LifeSkillKind.pesca,
        GearSource.forge => LifeSkillKind.herreria,
      };
}

/// One profession weapon: a weapon type (the base scales with the item
/// level), a signature affix it always carries and its es-AR names
/// (`data.gear.<id>.name` / `.legend`).
class ProfessionGearDef {
  const ProfessionGearDef(this.id, this.name, this.legend, this.source,
      this.type, this.signature,
      {this.flavor = ''});

  final String id;
  final String name;

  /// Name of its legendary version.
  final String legend;
  final GearSource source;

  /// Weapon type (`WeaponDef.type`).
  final String type;
  final UniqueMod signature;
  final String flavor;

  /// Manifest id of its icon (`items.gear_<id>`).
  String get sprite => 'gear_$id';
}

/// Fixed profession weapons (fish-forged ones are built per species:
/// [fishForgeType] / [fishForgeSignature]).
const kProfessionGear = <String, ProfessionGearDef>{
  // Cultivo: living wood, plants of the magitech past touched by echoes.
  'vivo_baston': ProfessionGearDef('vivo_baston', 'Bastón de madera viva',
      'Bastón del Bosque que Recuerda', GearSource.living, 'báculo',
      UniqueMod('de_la_vida', 40, 60),
      flavor: 'Sigue creciendo: una rama del pasado que todavía brota.'),
  'vivo_arco': ProfessionGearDef('vivo_arco', 'Arco de madera viva',
      'Arco de la Raíz Eterna', GearSource.living, 'arco',
      UniqueMod('certero', 5, 8),
      flavor: 'La cuerda es una enredadera que nunca se seca.'),
  'vivo_varita': ProfessionGearDef('vivo_varita', 'Varita de madera viva',
      'Varita del Brote Magitec', GearSource.living, 'varita',
      UniqueMod('runico', 4, 7),
      flavor: 'Un brote de los jardines magitec, con savia que zumba.'),
  'vivo_lanza': ProfessionGearDef('vivo_lanza', 'Lanza de madera viva',
      'Lanza del Tronco Antiguo', GearSource.living, 'lanza',
      UniqueMod('afilado', 4, 7),
      flavor: 'La punta es un nudo duro como el hierro.'),
  // v2 (profession_gear_v2.md § 5): every type but the rifle grows.
  'vivo_espada': ProfessionGearDef('vivo_espada', 'Espada de madera viva',
      'Espada del Brote que Vuelve', GearSource.living, 'espada',
      UniqueMod('afilado', 4, 7),
      flavor: 'La hoja es una corteza que se afila sola.'),
  'vivo_hacha': ProfessionGearDef('vivo_hacha', 'Hacha de madera viva',
      'Hacha de la Raíz Partida', GearSource.living, 'hacha',
      UniqueMod('feroz', 20, 30),
      flavor: 'Un nudo de raíz que el eco endureció.'),
  'vivo_dagas': ProfessionGearDef('vivo_dagas', 'Dagas de madera viva',
      'Dagas de las Dos Espinas', GearSource.living, 'dagas',
      UniqueMod('veloz', 5, 8),
      flavor: 'Dos espinas de un rosal que todavía no existe.'),
  'vivo_ballesta': ProfessionGearDef('vivo_ballesta',
      'Ballesta de madera viva', 'Ballesta del Tallo Tenso', GearSource.living,
      'ballesta', UniqueMod('letal', 10, 15),
      flavor: 'El arco es un tallo que nunca se afloja.'),
  'vivo_tomo': ProfessionGearDef('vivo_tomo', 'Tomo de madera viva',
      'Tomo de las Hojas que Recuerdan', GearSource.living, 'tomo',
      UniqueMod('arcano', 20, 30),
      flavor: 'Le salen hojas nuevas con lo que va a pasar.'),
  'vivo_espada_escudo': ProfessionGearDef('vivo_espada_escudo',
      'Espada y Escudo de madera viva', 'Baluarte del Bosque Quieto',
      GearSource.living, 'espada+escudo', UniqueMod('de_la_vida', 40, 60),
      flavor: 'El escudo es una corteza que se cierra sola.'),
  'vivo_maza_escudo': ProfessionGearDef('vivo_maza_escudo',
      'Maza y Escudo de madera viva', 'Maza del Tronco Sereno',
      GearSource.living, 'maza+escudo', UniqueMod('de_la_vida', 40, 60),
      flavor: 'Un nudo de tronco y una corteza que aguanta.'),
  'vivo_martillo_escudo': ProfessionGearDef('vivo_martillo_escudo',
      'Martillo y Escudo de madera viva', 'Martillo de la Raíz Profunda',
      GearSource.living, 'martillo+escudo', UniqueMod('rompedor', 5, 8),
      flavor: 'La cabeza es una raíz vieja, pesada como piedra.'),
  // Pesca: sunken echo weapons from deep water.
  'hundido_sable': ProfessionGearDef('hundido_sable', 'Sable hundido del eco',
      'Sable de la Marea Quieta', GearSource.sunken, 'espada',
      UniqueMod('gelido', 1, 1),
      flavor: 'Lo perdió alguien que todavía no nació.'),
  'hundido_tomo': ProfessionGearDef('hundido_tomo', 'Tomo empapado del eco',
      'Tomo del Archivo Sumergido', GearSource.sunken, 'tomo',
      UniqueMod('arcano', 20, 30),
      flavor: 'Las páginas mojadas se leen igual: el futuro no se borra.'),
  'hundido_ballesta': ProfessionGearDef('hundido_ballesta',
      'Ballesta de coral hundida', 'Ballesta del Arrecife Dormido',
      GearSource.sunken, 'ballesta', UniqueMod('letal', 10, 15),
      flavor: 'El coral creció sobre un mecanismo magitec.'),
  'hundido_dagas': ProfessionGearDef('hundido_dagas', 'Dagas de ancla hundida',
      'Dagas del Último Puerto', GearSource.sunken, 'dagas',
      UniqueMod('veloz', 5, 8),
      flavor: 'Dos eslabones de un ancla que el lago devolvió.'),
  // Herrería: forge-only weapons.
  'forja_martillo': ProfessionGearDef('forja_martillo',
      'Martillo y Escudo del yunque magitec', 'Martillo del Primer Yunque',
      GearSource.forge, 'martillo+escudo', UniqueMod('rompedor', 5, 8),
      flavor: 'Se templó con una chispa del pasado avanzado.'),
  'forja_hacha': ProfessionGearDef('forja_hacha', 'Hacha de fragua magitec',
      'Hacha de la Fragua sin Tiempo', GearSource.forge, 'hacha',
      UniqueMod('abrasador', 1, 1),
      flavor: 'El filo nunca termina de enfriarse.'),
  'forja_rifle': ProfessionGearDef('forja_rifle', 'Rifle de engranajes',
      'Rifle del Mecanismo Eterno', GearSource.forge, 'rifle',
      UniqueMod('veloz', 5, 8),
      flavor: 'Cada engranaje recuerda el giro del anterior.'),
  'forja_dagas': ProfessionGearDef('forja_dagas', 'Dagas de chispa',
      'Dagas del Resorte Vivo', GearSource.forge, 'dagas',
      UniqueMod('certero', 5, 8),
      flavor: 'Saltan de la mano como un resorte.'),
};

/// The fixed gear of [s].
List<ProfessionGearDef> gearOf(GearSource s) =>
    [for (final g in kProfessionGear.values) if (g.source == s) g];

// ---------------- weapon seeds (profession_gear.md § 3) ----------------

/// A weapon seed: grows the living weapon [gear]; an [ancient] one can
/// reach Legendary.
class WeaponSeedDef {
  const WeaponSeedDef(this.id, this.gear, {this.ancient = false});
  final String id;
  final String gear;
  final bool ancient;

  /// Manifest id of its icon (`items.gear_<id>`).
  String get sprite => 'gear_$id';
}

/// Plot `seed` ids of living weapons start with this.
const kWeaponSeedPrefix = 'ws_';

final kWeaponSeeds = <String, WeaponSeedDef>{
  'ws_baston': const WeaponSeedDef('ws_baston', 'vivo_baston'),
  'ws_arco': const WeaponSeedDef('ws_arco', 'vivo_arco'),
  'ws_varita': const WeaponSeedDef('ws_varita', 'vivo_varita'),
  'ws_lanza': const WeaponSeedDef('ws_lanza', 'vivo_lanza'),
  'ws_baston_old': const WeaponSeedDef('ws_baston_old', 'vivo_baston', ancient: true),
  'ws_arco_old': const WeaponSeedDef('ws_arco_old', 'vivo_arco', ancient: true),
  'ws_varita_old':
      const WeaponSeedDef('ws_varita_old', 'vivo_varita', ancient: true),
  'ws_lanza_old': const WeaponSeedDef('ws_lanza_old', 'vivo_lanza', ancient: true),
  // v2: every type but the rifle (profession_gear_v2.md § 5).
  for (final k in kLivingV2Keys) ...{
    'ws_$k': WeaponSeedDef('ws_$k', 'vivo_$k'),
    'ws_${k}_old': WeaponSeedDef('ws_${k}_old', 'vivo_$k', ancient: true),
  },
};

/// Keys of the living weapons added in v2 (`vivo_<key>`, `ws_<key>`).
const kLivingV2Keys = [
  'espada',
  'hacha',
  'dagas',
  'ballesta',
  'tomo',
  'espada_escudo',
  'maza_escudo',
  'martillo_escudo',
];

/// Plot seed of a living weapon being regrown (replant, § 3.5): the item
/// uid follows the prefix.
const kRegrowPrefix = 'wr_';

/// Compost (fertilizer id) → the affix it gives a living weapon
/// (profession_gear.md § 3.3). Value range scales with the item level.
const kCompostAffix = <String, UniqueMod>{
  'abono': UniqueMod('de_la_vida', 20, 30),
  'abono_runico': UniqueMod('runico', 3, 5),
  'abono_eco': UniqueMod('impetuoso', 6, 10),
  'abono_brasa': UniqueMod('abrasador', 1, 1),
  'abono_miel': UniqueMod('del_vampiro', 3, 5),
  'abono_escarcha': UniqueMod('gelido', 1, 1),
};

/// The top compost: needed (× `livingLegendCompost`) for a Legendary.
const kTopCompost = 'abono_eco';

// ---------------- fish forge (profession_gear.md § 4.2) ----------------

const _forgeTypes = [
  'espada',
  'lanza',
  'báculo',
  'arco',
  'tomo',
  'dagas',
  'hacha',
  'varita',
];

/// Weapon type Brann forges from the legendary fish [species].
String fishForgeType(String species) {
  final h = species.codeUnits.fold(7, (a, c) => (a * 31 + c) & 0x7fffffff);
  return _forgeTypes[h % _forgeTypes.length];
}

/// Signature affix of a weapon forged from [species] (by its theme).
UniqueMod fishForgeSignature(String species) {
  bool has(List<String> ws) => ws.any(species.contains);
  if (has(['escarcha', 'invierno', 'hielo', 'nev'])) {
    return const UniqueMod('gelido', 1, 1);
  }
  if (has(['fuego', 'brasa', 'forja', 'rescoldo'])) {
    return const UniqueMod('abrasador', 1, 1);
  }
  if (has(['reloj', 'archivo', 'olvido', 'era'])) {
    return const UniqueMod('impetuoso', 6, 10);
  }
  return const UniqueMod('feroz', 20, 30);
}

/// Gear id of a fish-forged weapon (`fish_<species>`).
String fishForgeGearId(String species) => 'fish_$species';

/// es-AR noun of a weapon type, for fish-forged names
/// (`data.gear.type.<key>`; key = [gearTypeKey]).
const kGearTypeNames = <String, String>{
  'espada': 'Espada',
  'lanza': 'Lanza',
  'báculo': 'Báculo',
  'arco': 'Arco',
  'tomo': 'Tomo',
  'dagas': 'Dagas',
  'hacha': 'Hacha',
  'varita': 'Varita',
  'ballesta': 'Ballesta',
  'rifle': 'Rifle',
  'espada+escudo': 'Espada y Escudo',
  'maza+escudo': 'Maza y Escudo',
  'martillo+escudo': 'Martillo y Escudo',
};

/// ASCII key of a weapon type (i18n keys can't carry accents or `+`).
String gearTypeKey(String type) =>
    type.replaceAll('á', 'a').replaceAll('+', '_');

/// `FarmTileAction.seed` prefix to replant a living weapon of the bag
/// (the item uid follows, profession_gear.md § 3.5).
const kRegrowItem = 'item:';

/// The square of tiles of radius `floor(r)` around ([tx], [ty]) (1 = 3×3,
/// 2 = 5×5): the area of the Tierra / Abono / Veta sub-paths.
List<(int, int)> squareTiles(int tx, int ty, double r) {
  final n = (r + 1e-6).floor();
  return [
    for (var dy = -n; dy <= n; dy++)
      for (var dx = -n; dx <= n; dx++) (tx + dx, ty + dy)
  ];
}

/// es-AR names of the weapon seeds (`data.gear.seed.<id>`).
const kWeaponSeedNames = <String, String>{
  'ws_baston': 'Semilla de bastón vivo',
  'ws_arco': 'Semilla de arco vivo',
  'ws_varita': 'Semilla de varita viva',
  'ws_lanza': 'Semilla de lanza viva',
  'ws_baston_old': 'Semilla antigua de bastón vivo',
  'ws_arco_old': 'Semilla antigua de arco vivo',
  'ws_varita_old': 'Semilla antigua de varita viva',
  'ws_lanza_old': 'Semilla antigua de lanza viva',
  'ws_espada': 'Semilla de espada viva',
  'ws_espada_old': 'Semilla antigua de espada viva',
  'ws_hacha': 'Semilla de hacha viva',
  'ws_hacha_old': 'Semilla antigua de hacha viva',
  'ws_dagas': 'Semilla de dagas vivas',
  'ws_dagas_old': 'Semilla antigua de dagas vivas',
  'ws_ballesta': 'Semilla de ballesta viva',
  'ws_ballesta_old': 'Semilla antigua de ballesta viva',
  'ws_tomo': 'Semilla de tomo vivo',
  'ws_tomo_old': 'Semilla antigua de tomo vivo',
  'ws_espada_escudo': 'Semilla de espada y escudo vivos',
  'ws_espada_escudo_old': 'Semilla antigua de espada y escudo vivos',
  'ws_maza_escudo': 'Semilla de maza y escudo vivos',
  'ws_maza_escudo_old': 'Semilla antigua de maza y escudo vivos',
  'ws_martillo_escudo': 'Semilla de martillo y escudo vivos',
  'ws_martillo_escudo_old': 'Semilla antigua de martillo y escudo vivos',
};
