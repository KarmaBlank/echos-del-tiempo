import 'dart:math' as math;

import '../data/farming_catalog.dart';
import '../data/tuning_catalog.dart';
import '../models/player_profile.dart';
import '../models/world_save.dart';
import 'life_craft_rules.dart';
import 'town_rules.dart';

/// Costo de un rango de mejora o de contratar.
typedef HelperCost = ({int gold, Map<String, int> mats, int level});

/// Progresión de cada ayudante (farming.md § 8.5, v0.27.0): nivel por XP
/// de trabajo y mejoras por rangos que cuestan oro y materiales de oficio.
/// Puras; los números en `kTuning[TuningId.town]`.
abstract final class HelperRules {
  static TuningDef get t => tuning(TuningId.town);

  static int get maxLevel => math.max(1, t.i('helperMaxLevel'));

  /// XP para pasar del nivel [l] al siguiente.
  static int xpToNext(int l) =>
      math.max(1, (t.d('helperXpBase') * math.pow(l, t.d('helperXpExp'))).round());

  /// Nivel de [st] (1 … [maxLevel]).
  static int level(HelperStat st) {
    var l = 1, xp = st.xp;
    while (l < maxLevel && xp >= xpToNext(l)) {
      xp -= xpToNext(l);
      l++;
    }
    return l;
  }

  /// XP dentro del nivel y la que falta para el siguiente (0 al tope).
  static (int, int) progress(HelperStat st) {
    var l = 1, xp = st.xp;
    while (l < maxLevel && xp >= xpToNext(l)) {
      xp -= xpToNext(l);
      l++;
    }
    return l >= maxLevel ? (0, 0) : (xp, xpToNext(l));
  }

  /// [b] con [n] de XP más para el ayudante [i].
  static TownBuild gainXp(TownBuild b, int i, int n) {
    if (n <= 0 || i < 0 || i >= b.helper) return b;
    final st = b.stat(i);
    return b.copyWith(crew: b.crewWith(i, st.copyWith(xp: st.xp + n)));
  }

  /// Material de oficio de cada tipo: fibra para granjeros, cebo para
  /// pescadores.
  static String matOf(BuildKind k) => k == BuildKind.huerta ? 'fibra' : 'cebo';

  static List<HelperUpgrade> upgradesOf(BuildKind k) => [
        for (final u in HelperUpgrade.values)
          if (u.farmer == (k == BuildKind.huerta)) u
      ];

  static int get maxRank => math.max(1, t.i('upMaxRank'));

  /// Costo de contratar uno más en una construcción de tipo [k].
  static HelperCost hireCost(BuildKind k) => (
        gold: t.i('helperCost'),
        mats: {matOf(k): t.i('hireMat')}..removeWhere((_, v) => v <= 0),
        level: t.i('helperLevel'),
      );

  /// Costo del rango [r] (1 = el primero) de una mejora en [k].
  static HelperCost upgradeCost(BuildKind k, int r) => (
        gold: t.i('upGold') * r,
        mats: {
          matOf(k): t.i('upMat') * r,
          if (r > 1) 'tabla': t.i('upTabla') * (r - 1),
        }..removeWhere((_, v) => v <= 0),
        level: 1 + (r - 1) * math.max(0, t.i('upRankLevels')),
      );

  static String costText(HelperCost c) => [
        '${c.gold} de oro',
        for (final e in c.mats.entries)
          '${e.value} ${kLifeMaterials[e.key]?.name.toLowerCase() ?? e.key}',
      ].join(' + ');

  /// Por qué [p] no puede pagar [c] (o `null`).
  static String? cannotPay(PlayerProfile p, HelperCost c) {
    if (p.credits < c.gold) return 'Falta oro (${p.credits}/${c.gold})';
    for (final e in c.mats.entries) {
      final have = p.life.craft(e.key);
      if (have < e.value) {
        final n = kLifeMaterials[e.key]?.name ?? e.key;
        return 'Falta $n ($have/${e.value}): se hace en el TALLER DE OFICIOS';
      }
    }
    return null;
  }

  /// [p] con [c] pagado; `null` si no alcanza.
  static PlayerProfile? pay(PlayerProfile p, HelperCost c) {
    if (cannotPay(p, c) != null) return null;
    final next = LifeCraftRules.spend(p, c.mats);
    return next?.copyWith(credits: next.credits - c.gold);
  }

  /// Por qué no se puede mejorar [u] del ayudante [i] de [b] (o `null`).
  static String? cannotUpgrade(
      PlayerProfile p, TownBuild b, int i, HelperUpgrade u) {
    if (i < 0 || i >= b.helper) return 'Ese ayudante ya no está';
    if (u.farmer != (b.kind == BuildKind.huerta)) return 'No es de este oficio';
    final st = b.stat(i);
    final r = st.rank(u) + 1;
    if (r > maxRank) return 'Rango máximo';
    final c = upgradeCost(b.kind, r);
    final lvl = level(st);
    if (lvl < c.level) return 'El ayudante necesita nivel ${c.level} (tiene $lvl)';
    return cannotPay(p, c);
  }

  static (PlayerProfile, TownState)? upgrade(
      PlayerProfile p, TownState s, String id, int i, HelperUpgrade u) {
    final b = s.build(id);
    if (b == null || cannotUpgrade(p, b, i, u) != null) return null;
    final st = b.stat(i);
    final r = st.rank(u) + 1;
    final paid = pay(p, upgradeCost(b.kind, r));
    if (paid == null) return null;
    return (
      paid,
      s.withBuild(b.copyWith(
          crew: b.crewWith(i, st.copyWith(ups: {...st.ups, u: r})))),
    );
  }

  // ---------------- efectos ----------------

  /// Parcelas que atiende el granjero [i] de [b].
  static int plotsOf(TownBuild b, int i) =>
      math.max(1, t.i('helperPlots')) +
      t.i('upPlots') * b.stat(i).rank(HelperUpgrade.parcelas);

  /// Chance de hacer una vuelta extra.
  static double extraChance(TownBuild b, int i) =>
      (t.d('upRitmo') *
              b.stat(i).rank(b.kind == BuildKind.huerta
                  ? HelperUpgrade.ritmo
                  : HelperUpgrade.ritmoRed))
          .clamp(0.0, 1.0);

  /// Chance de que una cosecha suba un escalón de calidad.
  static double qualityChance(TownBuild b, int i) =>
      (t.d('upCalidad') * b.stat(i).rank(HelperUpgrade.calidad)).clamp(0.0, 1.0);

  /// Chance de encontrar una semilla rara al cosechar.
  static double rareSeedChance(TownBuild b, int i) =>
      (t.d('upRareSeed') * b.stat(i).rank(HelperUpgrade.hallazgo))
          .clamp(0.0, 1.0);

  /// Peces de más por vuelta del pescador [i].
  static int extraFish(TownBuild b, int i) =>
      t.i('upPeces') * b.stat(i).rank(HelperUpgrade.red);

  /// Chance de tirar dos veces y quedarse con el pez más raro.
  static double rareFishChance(TownBuild b, int i) =>
      (t.d('upRareza') * b.stat(i).rank(HelperUpgrade.rareza)).clamp(0.0, 1.0);

  /// Qué hace cada rango de [u] (detalle de la casilla).
  static String effectText(HelperUpgrade u) {
    String pct(String k) => '${(t.d(k) * 100).round()} %';
    return switch (u) {
      HelperUpgrade.parcelas => '+${t.i('upPlots')} parcelas que atiende',
      HelperUpgrade.ritmo ||
      HelperUpgrade.ritmoRed =>
        '+${pct('upRitmo')} de chance de una vuelta extra',
      HelperUpgrade.calidad =>
        '+${pct('upCalidad')} de chance de subir la calidad',
      HelperUpgrade.hallazgo =>
        '+${pct('upRareSeed')} de chance de una semilla rara al cosechar',
      HelperUpgrade.red => '+${t.i('upPeces')} pez por vuelta',
      HelperUpgrade.rareza =>
        '+${pct('upRareza')} de chance de un pez mejor',
    };
  }

  // ---------------- bloqueo (farming.md § 8.6) ----------------

  /// Por qué el ayudante [i] de [b] está BLOQUEADO: no puede hacer
  /// ninguna de sus tareas ni ahora ni en ninguna vuelta futura sin que un
  /// jugador cambie algo. Vacía = no está bloqueado (trabaja o espera a
  /// que algo crezca o se seque). Igual en host y clientes: sale del
  /// estado del pueblo.
  static List<String> blockers(TownBuild b, int i) {
    if (i < 0 || i >= b.helper) return const [];
    final full = TownRules.chestFull(b);
    if (b.kind == BuildKind.lago) {
      return full ? const ['El cofre está lleno'] : const [];
    }
    if (b.kind != BuildKind.huerta) return const [];
    final area = TownRules.helperArea(b, i);
    if (area.isEmpty) return const ['No hay parcelas asignadas'];
    final m = b.taskMask(i);
    if (m & kAllHelperTasks == 0) return const ['No tiene tareas prendidas'];
    bool on(HelperTask t) => m & t.bit != 0;
    final plots = [
      for (final (x, y) in area) b.plots[plotKey(x, y)]
    ];
    final seeds = b.seedTotal > 0;
    final empty = plots.any((p) => p == null || !p.planted);
    // Living weapon plots are the players' to pick (farming.md § 8.2).
    final anyPlanted = plots.any((p) =>
        p != null && p.planted && kCrops.containsKey(p.seed));
    // Llega a madurar sola: el granjero riega solo en cada vuelta
    // (farming.md § 8.2), así que todo lo plantado madura.
    final harvest = on(HelperTask.cosechar) && !full && anyPlanted;
    // Algo que puede hacer ahora o más adelante solo (regar solo no
    // cuenta: lo hace siempre, pero sin cosechar no avanza).
    final can =
        (on(HelperTask.plantar) && seeds && (empty || harvest)) || harvest;
    if (can) return const [];
    final out = <String>[];
    if (on(HelperTask.plantar) && !seeds) out.add('Sin semillas para plantar');
    if (on(HelperTask.cosechar) && full && anyPlanted) {
      out.add('El cofre está lleno');
    }
    if (on(HelperTask.plantar) && seeds && !empty) {
      out.add('Todas sus parcelas están plantadas');
    }
    if (out.isEmpty) out.add('No tiene nada para hacer con sus tareas');
    return out;
  }

  static bool blocked(TownBuild b, int i) => blockers(b, i).isNotEmpty;

  /// Texto del cofre de [b] para el tooltip del mapa (farming.md § 8.3).
  static String chestText(TownBuild b) => b.chestTotal <= 0
      ? 'Cofre vacío'
      : TownRules.chestFull(b)
          ? 'Cofre lleno'
          : 'Cofre: ${b.chestTotal} ${b.chestTotal == 1 ? 'objeto' : 'objetos'}';
}
