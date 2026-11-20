import 'dart:ui';

import '../../../../game_engine/data/passive_tree_catalog.dart';
import '../../../../game_engine/rules/display_names.dart';
import 'fx_style.dart';
import 'ult_cinematic.dart';

/// Tiempos de los efectos de los disparadores del árbol (procs). Los
/// comparten la escena (`battle_fx.dart`) y el sonido
/// (`session_sfx.dart`) para caer en el mismo ms. Ver
/// docs/specs/battle_presentation.md § "Disparadores del árbol (procs)".
abstract final class ProcTiming {
  /// Lo secundario arranca este tiempo después del golpe primario.
  static const afterMs = 120;

  /// Separación entre carteles de nombre del mismo actor en un paso.
  static const tagStaggerMs = 180;

  /// Separación entre saltos de un rebote.
  static const hopMs = 130;

  /// El número y el tajo de un salto caen esto después del arco.
  static const hopHitMs = 60;

  /// Combustión: la bola de fuego (un `proj`) llega a los demás enemigos.
  static const blastHitMs = 280;
  static const blastStaggerMs = 50;

  /// Eco Arcano: la repetición fantasma arranca después del original.
  static const echoLagMs = 220;
  static const echoStaggerMs = 60;

  /// Contraataque: el tajo de vuelta después de que se lanza el héroe.
  static const counterHitMs = 80;

  /// Castigo Divino: el daño cuando el rayo llega abajo.
  static const beamHitMs = 180;

  /// Plaga Contagiosa: el chorro llega al nuevo huésped.
  static const streamMs = 450;

  /// Sed de Sangre: la cura después del latido.
  static const healAfterMs = 100;

  /// Danza de Cuchillas: el cartel `¡OTRA VEZ!` después del congelado,
  /// y el hit-stop del congelado.
  static const bannerMs = 150;
  static const timeStopHoldMs = 90;

  /// Hora base de los procs de una acción: 0 sin acción (inicio de
  /// turno); en una ULT el regreso de su guion (después de todos los
  /// impactos); si no, el golpe más tardío de la acción + [afterMs].
  static int base({required bool inAction, int hitMs = 0, UltScript? ult}) {
    if (!inAction) return 0;
    if (ult != null) return ult.returnAt;
    return hitMs + afterMs;
  }

  /// Arco del salto [hop] (0, 1, ...).
  static int hopAt(int base, int hop) => base + hop * hopMs;

  /// Golpe del salto [hop].
  static int hopHitAt(int base, int hop) => hopAt(base, hop) + hopHitMs;

  /// Bola de fuego de Combustión al enemigo [i] (sin contar el centro).
  static int blastHitAt(int base, int i) =>
      base + blastHitMs + i * blastStaggerMs;

  /// Proyectil fantasma de Eco Arcano al objetivo [i].
  static int echoAt(int base, int i) => base + echoLagMs + i * echoStaggerMs;

  /// Cartel [k] (0, 1, ...) de un actor en el paso.
  static int tagAt(int base, int k) => base + (k % 4) * tagStaggerMs;
}

/// Ids de las mecánicas que rebotan (el `sourceId` del daño del salto).
const Set<String> kChainMechanics = {
  'rebote',
  'corteCadena',
  'arcoVoltaico',
  'arcoDormido',
};

/// Mecánicas de keystones (cartel rojo); el resto son notables (dorado).
final Set<String> kKeystoneMechanics = {
  for (final n in kPassiveTree.nodes.values)
    if (n.kind == 'k' && n.mechanicId != null) n.mechanicId!,
};

const procNotableColor = Color(0xFFFFD166);
const procKeystoneColor = Color(0xFFFF4757);

/// Color del cartel de la mecánica [id].
Color procTagColor(String id) =>
    kKeystoneMechanics.contains(id) ? procKeystoneColor : procNotableColor;

/// Nombre que muestra el cartel: siempre legible (`displayName`).
String procName(String id) => displayName(id);

/// Color y elemento del daño secundario de [sourceId] (rebotes,
/// estallido, reflejo, sagrado). `null`: el de la acción (Eco Arcano).
(Color, FxElement)? procHitStyle(String sourceId) => switch (sourceId) {
      'rebote' => (const Color(0xFF81ECEC), FxElement.phys),
      'corteCadena' => (const Color(0xFFFF6B81), FxElement.phys),
      'arcoVoltaico' => (const Color(0xFF74B9FF), FxElement.mana),
      'arcoDormido' => (const Color(0xFFA29BFE), FxElement.arcane),
      'combustion' => (const Color(0xFFFF7B29), FxElement.burn),
      'contraataque' => (fxWhite, FxElement.phys),
      'castigoDivino' => (const Color(0xFFFFD166), FxElement.holy),
      // La cura que quema a un no muerto (bestiary.md § 1.1): luz.
      'curaSagrada' => (const Color(0xFFFFF3B0), FxElement.holy),
      _ => null,
    };

/// Colores de los efectos de procs (arte, como `fx_style.dart`).
abstract final class ProcColors {
  static const shield = Color(0xFFFFEAA7);
  static const frenzy = Color(0xFFFF6B81);
  static const retaliate = Color(0xFFFF9F43);
  static const weaken = Color(0xFF7BED9F);
  static const mark = Color(0xFFFF4757);
  static const blood = Color(0xFFD63031);
  static const plague = Color(0xFF7BED9F);
  static const stun = Color(0xFFFFEAA7);
  static const ult = Color(0xFFA29BFE);
  static const timeStop = Color(0xFFBFEFFF);
  static const lastStand = Color(0xFFFF4757);
}

/// Vapor de Choque Térmico.
const kSteamFx = ElementFx([
  Color(0xFFFFFFFF),
  Color(0xFFDFE6E9),
  Color(0xFFB2BEC3),
  Color(0xFF81ECEC)
], 16, 26, -60, 0.7, ParticleShape.bubble);

/// Chispas doradas de Guardián.
const kSparkFx = ElementFx(
    [Color(0xFFFFD166), Color(0xFFFFF3B0), Color(0xFFA29BFE)],
    12,
    30,
    -70,
    0.7,
    ParticleShape.ray);

/// Astillas del escudo que se quiebra.
const kShardFx = ElementFx(
    [Color(0xFFFFEAA7), Color(0xFFFFFFFF), Color(0xFFFFF3B0)],
    7,
    55,
    120,
    0.35,
    ParticleShape.shard);

/// Brillo del escudo al armarse.
const kShieldFx = ElementFx([Color(0xFFFFEAA7), Color(0xFFFFFFFF)], 8, 18, -30,
    0.6, ParticleShape.plus);
