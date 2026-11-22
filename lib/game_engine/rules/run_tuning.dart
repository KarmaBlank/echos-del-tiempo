import '../data/tuning_catalog.dart';
import '../models/run_state.dart';

/// Números de la Travesía (docs/specs/roguelike.md), todos juntos. Una
/// fase posterior los pasa al Editor de la Travesía; mientras tanto, el
/// único lugar para tocarlos es este.
abstract final class RunTuning {
  // ---------------- Mapa (§ 2) ----------------

  /// Pisos de una run.
  static const floors = 3;

  /// Líneas principales por piso.
  static const lanes = 3;

  /// Capas de nodos antes del jefe (la última es de descanso).
  static const layers = 15;

  /// Probabilidad de que una línea se abra en dos nodos en una capa.
  static const splitChance = 0.12;

  /// Probabilidad de un cruce hacia una línea vecina entre dos capas.
  static const crossChance = 0.09;

  /// Capa mínima (desde 0) de la primera élite.
  static const firstEliteLayer = 4;

  /// Pesos del sorteo de tipo de nodo (las capas fijas aparte).
  static const weightCombate = 50;
  static const weightElite = 14;
  static const weightTienda = 9;
  static const weightArmeria = 9;
  static const weightDescanso = 10;

  // ---------------- Enemigos ----------------

  /// Nivel de los enemigos: base + piso × porPiso + capa × porCapa. Piso
  /// y capa están en el grupo de ajustes «Travesía» (Editor → Balance).
  static const levelBase = 1;
  static int get levelPerFloor =>
      tuning(TuningId.travesia).i('levelPerFloor');
  static double get levelPerLayer =>
      tuning(TuningId.travesia).d('levelPerLayer');

  /// Niveles extra de la élite y del jefe.
  static const eliteLevelBonus = 1;
  static const bossLevelBonus = 2;

  // ---------------- Personaje de la run ----------------

  /// Oro con el que arranca cada personaje.
  static const startGold = 60;

  /// Oro por pelea ganada (además de la recompensa).
  static const goldCombate = 12;
  static const goldElite = 25;
  static const goldJefe = 50;

  /// Vida y maná que cura el descanso (fracción del máximo).
  static const restHeal = 0.6;

  // ---------------- Recompensas (§ 4) ----------------

  /// Opciones por fila.
  static const offerSize = 3;

  /// Ofertas seguidas sin la rama principal antes de garantizarla.
  static const pityAfter = 2;

  /// Probabilidad de que la primera opción del árbol siga la tendencia.
  static const trendChance = 0.75;

  /// Probabilidad de que la segunda opción salga de una rama con sinergia.
  static const synergyChance = 0.6;

  /// Armas ofrecidas hasta este nivel por encima del de los enemigos de
  /// la entrada del piso (el personaje no tiene nivel, § 5).
  static int get weaponLevelAhead =>
      tuning(TuningId.travesia).i('weaponLevelAhead');

  /// Oro de la fila Extra: base + piso × porPiso.
  static const extraGoldBase = 40;
  static const extraGoldPerFloor = 25;

  /// Pociones / Éter de la fila Extra.
  static const extraPotions = 2;
  static const extraEthers = 1;

  /// Puntos de atributo de la fila Extra (grupo «Travesía»).
  static int get extraAttribute => tuning(TuningId.travesia).i('attrReward');

  /// ULT de rama que se ofrecen tras un jefe (siempre) o una élite.
  static const ultOfferSize = 3;

  /// Probabilidad de que la recompensa traiga la fila ULT, por tipo de
  /// pelea (grupo «Travesía»): rara en combate, a veces en élite, casi
  /// siempre en el jefe.
  static double ultChance(RunNodeType t) => tuning(TuningId.travesia).d(
      switch (t) {
        RunNodeType.jefe => 'ultChanceJefe',
        RunNodeType.elite => 'ultChanceElite',
        _ => 'ultChanceCombate',
      });

  /// Cuántas ULT trae la fila: 1 a [ultOfferSize] (con [roll] en 0..1:
  /// las de 1 opción son las más comunes).
  static int ultCount(double roll) => roll < 0.5
      ? 1
      : roll < 0.8
          ? 2
          : ultOfferSize;

  /// Habilidades libres equipables: el tope total (`maxSkills`) menos
  /// ATACAR y DEFENDER; las del arma no cuentan (§ 12.2).
  static int get freeSkillSlots =>
      tuning(TuningId.travesia).i('maxSkills') - 2;

  /// Mejora de habilidad libre en la armería.
  static int skillUpCost(int nextLevel) =>
      tuning(TuningId.travesia).i('skillUpCost') * nextLevel;
  static double get skillUpPower =>
      tuning(TuningId.travesia).d('skillUpPower');
  static int get skillUpMax => tuning(TuningId.travesia).i('skillUpMax');

  /// ULT a la venta en cada tienda y su precio (grupo «Travesía»).
  static int get shopUlts => tuning(TuningId.travesia).i('shopUlts');
  static int get ultPrice => tuning(TuningId.travesia).i('ultPrice');
}
