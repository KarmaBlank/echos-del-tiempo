import 'dart:ui';

import '../../../../app/theme/vision_palette.dart';

import '../../../../game_engine/data/ascension_catalog.dart';
import '../../../../game_engine/data/branch_ults_catalog.dart'
    show kBranchUltLooks, kWeaponUltSkills;
import '../../../../game_engine/data/skill_variants_catalog.dart';
import '../../../../game_engine/data/skills_catalog.dart';
import '../../../../game_engine/models/skill.dart';
import '../../../../game_engine/models/status.dart';

/// Colores, elementos y partículas del prototipo (`SK[].col`, `el`,
/// `STATUS[].col`, `STLET`, `ELFX`). Son **arte**: no pasan por
/// `RetroPalette` (docs/specs/ui_style.md § "Arte vs. chrome"). Números
/// en docs/specs/battle_presentation.md.

/// Elemento visual de un golpe (`el` / `skEl` del prototipo).
enum FxElement {
  phys,
  burn,
  freeze,
  poison,
  arcane,
  holy,
  heal,
  mana,
  level,
  stun
}

/// Elemento visual de un estado (`st.k` usado como elemento).
FxElement elementOfStatus(StatusKind k) => switch (k) {
      StatusKind.burn => FxElement.burn,
      StatusKind.poison => FxElement.poison,
      StatusKind.freeze => FxElement.freeze,
      StatusKind.stun => FxElement.stun,
      StatusKind.holy => FxElement.holy,
      StatusKind.regen => FxElement.heal,
      StatusKind.wet => FxElement.mana,
      StatusKind.charged => FxElement.stun,
    };

/// `STATUS[k].col`.
Color statusColor(StatusKind k) => switch (k) {
      StatusKind.burn => const Color(0xFFFF7B29),
      StatusKind.poison => const Color(0xFF7BED9F),
      StatusKind.freeze => const Color(0xFF74B9FF),
      StatusKind.stun => const Color(0xFFFFEAA7),
      StatusKind.holy => const Color(0xFFFFF3B0),
      StatusKind.regen => const Color(0xFF55EFC4),
      StatusKind.wet => const Color(0xFF3FA9F5),
      StatusKind.charged => const Color(0xFFC77DFF),
    };

/// `STLET[k]`: letra de la insignia.
String statusLetter(StatusKind k) => switch (k) {
      StatusKind.burn => 'Q',
      StatusKind.poison => 'V',
      StatusKind.freeze => 'C',
      StatusKind.stun => 'A',
      StatusKind.holy => 'S',
      StatusKind.regen => 'R',
      StatusKind.wet => 'M',
      StatusKind.charged => 'E',
    };

/// Color (`col`) de cada habilidad y ULT por `SkillDef.id`.
const Map<String, Color> kSkillColors = {
  'giro': Color(0xFFDFE6E9),
  'embestida': Color(0xFFFAB1A0),
  'ignea': Color(0xFFFF7B29),
  'sismo': Color(0xFFE1B12C),
  'hendir': Color(0xFF7BED9F),
  'tajoT': Color(0xFFA29BFE),
  'chispa': Color(0xFFFF9F43),
  'cura': Color(0xFF7BED9F),
  'bola': Color(0xFFFF7B29),
  'llamarada': Color(0xFFE17055),
  'lanzaH': Color(0xFF74B9FF),
  'ventisca': Color(0xFF81ECEC),
  'prisa': Color(0xFFFFD166),
  'detener': Color(0xFFA29BFE),
  'curaM': Color(0xFF55EFC4),
  'rafaga': Color(0xFFFDCB6E),
  'venenosa': Color(0xFF7BED9F),
  'certero': Color(0xFFFF6B81),
  'aturdir': Color(0xFFA29BFE),
  'rayoF': Color(0xFFFFE066),
  'lluvia': Color(0xFFFDCB6E),
  'sagrado': Color(0xFFFFEAA7),
  'provocar': Color(0xFFFF7675),
  'escudoFe': Color(0xFF74B9FF),
  'bendicion': Color(0xFFFFEAA7),
  'lanzaLuz': Color(0xFFFFF3B0),
  'consagrar': Color(0xFFFDCB6E),
  'juicio': Color(0xFFFFD166),
  'corteGlacial': Color(0xFF81ECEC),
  'erupcion': Color(0xFFE17055),
  'dardo': Color(0xFF55EFC4),
  'niebla': Color(0xFF7BED9F),
  'infierno': Color(0xFFD63031),
  'saeta': Color(0xFF74B9FF),
  'metralla': Color(0xFFBADC58),
  'aura': Color(0xFF7BED9F),
  'fortaleza': Color(0xFF74B9FF),
  'proteccion': Color(0xFFFFEAA7),
  'estocada': Color(0xFFDFE6E9),
  'temblor': Color(0xFFE1B12C),
  'sanar': Color(0xFF7BED9F),
  'golpeEscudo': Color(0xFFDFE6E9),
  'aplastar': Color(0xFFFFD166),
  'tajoCarmesi': Color(0xFFD63031),
  'vendaval': Color(0xFF81ECEC),
  'tajoOcaso': Color(0xFF6C5CE7),
  'descarga': Color(0xFFFFE066),
  'plaga': Color(0xFFBADC58),
  'sombra': Color(0xFF6C5CE7),
  'ceroAbs': Color(0xFF74B9FF),
  'flechaSolar': Color(0xFFFDCB6E),
  'perfora': Color(0xFFFF4757),
  // loot v2: lanza, varita, ballesta y dagas.
  'perforar': Color(0xFFDFE6E9),
  'barrido': Color(0xFFFAB1A0),
  'empalar': Color(0xFFFF6B81),
  'misil': Color(0xFFA29BFE),
  'escarchaFugaz': Color(0xFF81ECEC),
  'rayoArcano': Color(0xFFE84393),
  'virote': Color(0xFFB2BEC3),
  'viroteIgneo': Color(0xFFFF7B29),
  'tajoGemelo': Color(0xFFDFE6E9),
  'abanico': Color(0xFF7BED9F),
  // ULTS
  'ult_espada': Color(0xFFFFFFFF),
  'ult_hacha': Color(0xFFE1B12C),
  'ult_baculo': Color(0xFFFF7B29),
  'ult_tomo': Color(0xFFA29BFE),
  'ult_arco': Color(0xFFFDCB6E),
  'ult_rifle': Color(0xFFFF4757),
  'ult_espada_escudo': Color(0xFF74B9FF),
  'ult_maza_escudo': Color(0xFFFFEAA7),
  'ult_martillo_escudo': Color(0xFFFFD166),
  'ult_lanza': Color(0xFFFF6B81),
  'ult_varita': Color(0xFFE84393),
  'ult_ballesta': Color(0xFFFF9F43),
  'ult_dagas': Color(0xFF55EFC4),
  // ---- kit y ULT de las ascensiones (docs/specs/ascension.md § 4) ----
  'sangria': Color(0xFFFF4757),
  'torbellino': Color(0xFFD63031),
  'gritoGuerra': Color(0xFFFFB142),
  'estandarte': Color(0xFFFFD166),
  'aceleron': Color(0xFFA29BFE),
  'grietaTemporal': Color(0xFF6C5CE7),
  'prismaElemental': Color(0xFFFF9F43),
  'detonar': Color(0xFFE17055),
  'tiroCabeza': Color(0xFFFF6B81),
  'apuntar': Color(0xFFFFEAA7),
  'trampaPuas': Color(0xFF7BED9F),
  'redCaza': Color(0xFFBADC58),
  'castigo': Color(0xFFFFEAA7),
  'luzCegadora': Color(0xFFFFF3B0),
  'ult_berserker': Color(0xFFFF4757),
  'ult_senorGuerra': Color(0xFFFFB142),
  'ult_cronomante': Color(0xFFA29BFE),
  'ult_elementalista': Color(0xFFFF9F43),
  'ult_francotirador': Color(0xFFFF6B81),
  'ult_trampero': Color(0xFF7BED9F),
  'ult_templario': Color(0xFFFFEAA7),
  'ult_guardian': Color(0xFF74B9FF),
};

/// Habilidades con `el` propio en el prototipo (todas sagradas).
const Set<String> kHolySkills = {
  'sagrado',
  'lanzaLuz',
  'juicio',
  'ult_maza_escudo',
  'ult_martillo_escudo',
  'castigo',
  'luzCegadora',
  'ult_templario',
};

/// Color de los dúos (`DUALS[].col`) por `dualKey`.
const Map<String, Color> kDualColors = {
  'guerrero+maga': Color(0xFFFF7B29),
  'guerrero+tirador': Color(0xFF7BED9F),
  'maga+tirador': Color(0xFF70A1FF),
  'guerrero+guerrero': Color(0xFFDFE6E9),
  'maga+maga': Color(0xFFE84393),
  'guerrero+paladin': Color(0xFFFFD166),
  'maga+paladin': Color(0xFFFFF3B0),
  'paladin+tirador': Color(0xFFFFEAA7),
  'paladin+paladin': Color(0xFFDFE6E9),
  'tirador+tirador': Color(0xFFFDCB6E),
};

const fxWhite = Color(0xFFFFFFFF);

/// Color de una habilidad (blanco si no está en la tabla). Las variantes
/// usan el de la habilidad a la que se parecen (`kSkillLooks`).
Color skillColor(String? id) =>
    kSkillColors[id] ??
    kSkillColors[kSkillLooks[id]] ??
    kSkillColors[kBranchUltLooks[id]] ??
    fxWhite;

/// `skEl(tk)`: `el` propio, si no el estado que aplica, si no `arc`
/// (mágica) o `phys`. Curas y escudos de las variantes: `heal` / `holy`.
FxElement skillElement(SkillDef sk) {
  if (kHolySkills.contains(sk.id) || kHolySkills.contains(kSkillLooks[sk.id])) {
    return FxElement.holy;
  }
  if (kSkillLooks.containsKey(sk.id)) {
    if (sk.drainHeal > 0) return FxElement.heal;
    if (sk.shields) return FxElement.holy;
  }
  final st = sk.status;
  if (st != null) return elementOfStatus(st.kind);
  return sk.kind == SkillKind.magical ? FxElement.arcane : FxElement.phys;
}

/// Todas las habilidades y ULT por `SkillDef.id` (las ULT de los tipos
/// de loot v2 incluidas: `kAllUltimates`).
final Map<String, SkillDef> kSkillsById = {
  for (final s in kSkills.values) s.id: s,
  for (final s in kAllUltimates.values) s.id: s,
  ...kAscensionUltimatesById,
  ...kWeaponUltSkills,
};

/// Tipos de arma a distancia (`ranged(p)`): sus golpes llevan proyectil.
const Set<String> kRangedWeaponTypes = {
  'arco',
  'rifle',
  'báculo',
  'tomo',
  'varita',
  'ballesta',
};

/// Cómo se dibuja un proyectil (docs/specs/battle_presentation.md
/// § "Catálogo de efectos").
enum ProjStyle {
  /// Orbe con estela del color de la habilidad (elemental).
  orb,

  /// Trazo blanco de 7 px (flecha / bala: físico).
  arrow,

  /// Virote de ballesta: trazo grueso con punta naranja y plumas.
  bolt,

  /// Misil arcano de varita: rombo violeta que zigzaguea con chispas.
  missile,
}

/// Cómo se dibuja el tajo sobre el golpeado.
enum SlashStyle {
  /// La X del prototipo.
  cross,

  /// Lanza: estocada horizontal que atraviesa, con punta.
  thrust,

  /// Dagas: dos cortes paralelos rápidos.
  twin,
}

/// Proyectil del arma [weaponType] para un golpe de elemento [el].
ProjStyle projStyleFor(String? weaponType, FxElement el) =>
    switch (weaponType) {
      'ballesta' => ProjStyle.bolt,
      'varita' => ProjStyle.missile,
      _ => el == FxElement.phys ? ProjStyle.arrow : ProjStyle.orb,
    };

/// Tajo del arma [weaponType] (del atacante) sobre el golpeado.
SlashStyle slashStyleFor(String? weaponType) => switch (weaponType) {
      'lanza' => SlashStyle.thrust,
      'dagas' => SlashStyle.twin,
      _ => SlashStyle.cross,
    };

/// Forma de una partícula (`k` de `ELFX`).
enum ParticleShape { square, shard, bubble, ray, plus }

/// Una entrada de `ELFX`.
class ElementFx {
  const ElementFx(
      this.colors, this.count, this.speed, this.gravity, this.life, this.shape);

  final List<Color> colors;
  final int count;
  final double speed;
  final double gravity;
  final double life;
  final ParticleShape shape;
}

/// `ELFX` del prototipo (los elementos sin entrada usan `phys`).
const Map<FxElement, ElementFx> kElementFx = {
  FxElement.phys: ElementFx(
      [Color(0xFFFFFFFF), Color(0xFFFFEAA7), Color(0xFFDFE6E9)],
      9,
      80,
      160,
      0.35,
      ParticleShape.square),
  FxElement.burn: ElementFx([
    Color(0xFFFF7B29),
    Color(0xFFFFD166),
    Color(0xFFE17055),
    Color(0xFFD63031)
  ], 18, 35, -70, 0.75, ParticleShape.square),
  FxElement.freeze: ElementFx([
    Color(0xFF74B9FF),
    Color(0xFFDFF9FB),
    Color(0xFF81ECEC),
    Color(0xFFFFFFFF)
  ], 14, 65, 40, 0.65, ParticleShape.shard),
  FxElement.poison: ElementFx([
    Color(0xFF7BED9F),
    Color(0xFFBADC58),
    Color(0xFF55EFC4),
    Color(0xFF20BF6B)
  ], 12, 22, -28, 1.0, ParticleShape.bubble),
  FxElement.arcane: ElementFx([
    Color(0xFFA29BFE),
    Color(0xFFE84393),
    Color(0xFFFFFFFF),
    Color(0xFF6C5CE7)
  ], 16, 75, 0, 0.5, ParticleShape.square),
  FxElement.holy: ElementFx(
      [Color(0xFFFFF3B0), Color(0xFFFFEAA7), Color(0xFFFFFFFF)],
      12,
      12,
      -45,
      0.85,
      ParticleShape.ray),
  FxElement.heal: ElementFx(
      [Color(0xFF7BED9F), Color(0xFF55EFC4), Color(0xFFFFFFFF)],
      10,
      14,
      -38,
      1.0,
      ParticleShape.plus),
  FxElement.mana: ElementFx(
      [Color(0xFF74B9FF), Color(0xFFA29BFE), Color(0xFFFFFFFF)],
      10,
      14,
      -38,
      1.0,
      ParticleShape.square),
  FxElement.level: ElementFx(
      [Color(0xFFFFD166), Color(0xFFFFF3B0), Color(0xFFFFFFFF)],
      30,
      22,
      -85,
      1.3,
      ParticleShape.ray),
};

ElementFx elementFx(FxElement el) =>
    kElementFx[el] ?? kElementFx[FxElement.phys]!;

// ------------------------------------------- quiebre y ULT enemigas
// (docs/specs/battle_presentation.md § "Quiebre" y § "ULT enemigas").

/// Amarillo de la barra de quiebre, `¡QUIEBRE!` y los golpes a un
/// enemigo quebrado (celeste con el modo daltónico).
const breakColor = VisionColor(VisionSlot.breakBar);

/// Destello de pantalla del quiebre.
const breakFlashColor = Color(0xFFFFF7C2);

/// Rojo de la carga de ULT enemiga y del aviso (violeta con el modo
/// daltónico).
const enemyUltBarColor = VisionColor(VisionSlot.enemyUlt);

/// Astillas de cristal del quiebre.
const kBreakShardFx = ElementFx([
  Color(0xFFFFE14D),
  Color(0xFFFFFFFF),
  Color(0xFFFFF7C2),
  Color(0xFFFFB142)
], 16, 95, 140, 0.55, ParticleShape.shard);

/// Color de cada ULT enemiga (`EnemyUltDef.id`).
const Map<String, Color> kEnemyUltColors = {
  'eult_diluvio': Color(0xFF7BED9F),
  'eult_engranaje': Color(0xFFE1B12C),
  'eult_finEras': Color(0xFFD63031),
  'eult_furia': Color(0xFFFF4757),
  'eult_nido': Color(0xFF9B59B6),
  'eult_aliento': Color(0xFF9FF3FF),
  'eult_juicio': Color(0xFF6FF7FF),
  'eult_coro': Color(0xFF7FF3FF),
  'eult_erupcion': Color(0xFFFF7B29),
  'eult_lamento': Color(0xFFB8C6FF),
  'eult_colapsoVacio': Color(0xFF9B59FF),
  // v0.8 · Jefes del Abismo.
  'eult_abismoReloj': Color(0xFFC39BFF),
  'eult_abismoEco': Color(0xFFC39BFF),
  'eult_abismoCorona': Color(0xFFB8C6FF),
  'eult_abismoEras': Color(0xFFD63031),
  'eult_primordial': Color(0xFFE8DFFF),
};

Color enemyUltColor(String? id) => kEnemyUltColors[id] ?? enemyUltBarColor;

/// Elemento de las partículas de cada ULT enemiga.
FxElement enemyUltElement(String? id) => switch (id) {
      'eult_diluvio' => FxElement.poison,
      'eult_engranaje' => FxElement.freeze,
      'eult_finEras' => FxElement.burn,
      'eult_nido' => FxElement.poison,
      'eult_aliento' => FxElement.freeze,
      'eult_juicio' => FxElement.arcane,
      'eult_coro' => FxElement.arcane,
      'eult_erupcion' => FxElement.burn,
      'eult_lamento' => FxElement.freeze,
      'eult_colapsoVacio' => FxElement.arcane,
      'eult_abismoReloj' => FxElement.freeze,
      'eult_abismoEco' => FxElement.arcane,
      'eult_abismoCorona' => FxElement.freeze,
      'eult_abismoEras' => FxElement.burn,
      'eult_primordial' => FxElement.arcane,
      _ => FxElement.phys,
    };

// ------------------------------------------------ mecánicas de jefe
// (docs/specs/battle_presentation.md § "Mecánicas de jefe").

/// Hilos de la telaraña.
const webColor = Color(0xFFEDEFF5);

/// Tinte del campo helado y los cristales.
const frostColor = Color(0xFF9FE3F0);

/// Postura de escudo (azul) y de espada (rojo).
const stanceShieldColor = Color(0xFF74B9FF);
const stanceSwordColor = Color(0xFFFF6B6B);

Color stanceColor(int stance) =>
    stance == 1 ? stanceShieldColor : stanceSwordColor;

// ---- v0.3 (docs/specs/bosses.md § "v0.3") ----

/// Brillo de los ecos de la Hechicera.
const echoColor = Color(0xFF7FF3FF);

/// Lava de la Bestia de Magma (borde / centro).
const lavaColor = Color(0xFFFF7B29);
const lavaCoreColor = Color(0xFFFFD166);

/// Aura de inmunidad del Espectro Coronado con su séquito.
const immuneColor = Color(0xFFB8C6FF);

/// Marca del Vacío del Centinela.
const voidMarkColor = Color(0xFFB57BFF);

/// Fase 2 del Devorador.
const phaseColor = Color(0xFFD63031);

/// Jefes del Abismo v0.8: avisos, sellos y distorsión.
const abyssColor = Color(0xFFC39BFF);

/// Escoria y brasas de la lava.
const kLavaFx = ElementFx([
  Color(0xFFFF7B29),
  Color(0xFFFFD166),
  Color(0xFFFF4500),
  Color(0xFF3B3B3B)
], 12, 80, 160, 0.6, ParticleShape.square);
