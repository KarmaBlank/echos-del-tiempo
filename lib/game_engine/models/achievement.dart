import 'item.dart';

/// Categorías de las Hazañas (docs/specs/achievements.md § 2), en el
/// orden de las secciones de la pestaña.
enum AchievementCategory {
  forge('FORJA'),
  fusion('FUSIÓN'),
  salvage('REFORJA Y DESARME'),
  inventory('INVENTARIO'),
  combat('COMBATE'),
  progression('PROGRESIÓN'),
  endgame('ENDGAME');

  const AchievementCategory(this.label);
  final String label;
}

/// Contadores de las hazañas por tiers (§ 1). Claves del JSON `ach.c`.
abstract final class AchievementCounter {
  static const forgeLevels = 'forgeLevels';
  static const fusions = 'fusions';
  static const salvaged = 'salvaged';

  // ---- ULT v2 (ultimates_v2.md § 3.4) ----
  static const flawlessWins = 'flawlessWins';
  static const breaks = 'breaks';
  static const bossUltCancels = 'bossUltCancels';
  static const allyShields = 'allyShields';
  static const weaponsPlus10 = 'weaponsPlus10';
  static const finishers = 'finishers';

  static const all = [
    forgeLevels,
    fusions,
    salvaged,
    flawlessWins,
    breaks,
    bossUltCancels,
    allyShields,
    weaponsPlus10,
    finishers,
  ];
}

/// Lo que paga una hazaña: créditos, materiales de forja / fusión y
/// pociones (§ 1). Inmutable.
class AchievementReward {
  const AchievementReward({
    this.credits = 0,
    this.esquirlas = 0,
    this.cristales = 0,
    this.prismas = 0,
    this.potions = 0,
    this.ethers = 0,
    this.ult,
  });

  /// ULT v2 que se aprende (ultimates_v2.md § 3.4); `null` = ninguna.
  final String? ult;

  final int credits;
  final int esquirlas, cristales, prismas;

  /// Pociones de vida / de maná.
  final int potions, ethers;

  Map<CraftMaterial, int> get materials => {
        if (esquirlas > 0) CraftMaterial.esquirla: esquirlas,
        if (cristales > 0) CraftMaterial.cristal: cristales,
        if (prismas > 0) CraftMaterial.prisma: prismas,
      };

  bool get isEmpty =>
      credits == 0 &&
      esquirlas == 0 &&
      cristales == 0 &&
      prismas == 0 &&
      potions == 0 &&
      ethers == 0 &&
      ult == null;

  AchievementReward operator +(AchievementReward o) => AchievementReward(
        credits: credits + o.credits,
        esquirlas: esquirlas + o.esquirlas,
        cristales: cristales + o.cristales,
        prismas: prismas + o.prismas,
        potions: potions + o.potions,
        ethers: ethers + o.ethers,
        ult: ult ?? o.ult,
      );

  /// Corto, para la fila y el toast: `+₵300 +1 Cristal de Era`.
  String get text => [
        if (credits > 0) '+₵$credits',
        if (esquirlas > 0) '+$esquirlas ${_n(esquirlas, 'Esquirla', 'Esquirlas')} del Eco',
        if (cristales > 0) '+$cristales ${_n(cristales, 'Cristal', 'Cristales')} de Era',
        if (prismas > 0) '+$prismas ${_n(prismas, 'Prisma Roto', 'Prismas Rotos')}',
        if (potions > 0) '+$potions ${_n(potions, 'Poción', 'Pociones')} de vida',
        if (ethers > 0) '+$ethers ${_n(ethers, 'Poción', 'Pociones')} de maná',
        if (ult != null) '+ULT',
      ].join(' ');

  /// Abreviado para la fila de una línea (§ 1): `₵300 · 1C · 2PV`.
  String get short => [
        if (credits > 0) '₵$credits',
        if (esquirlas > 0) '${esquirlas}E',
        if (cristales > 0) '${cristales}C',
        if (prismas > 0) '${prismas}P',
        if (potions > 0) '${potions}PV',
        if (ethers > 0) '${ethers}PM',
        if (ult != null) 'ULT',
      ].join(' · ');

  static String _n(int n, String one, String many) => n == 1 ? one : many;
}

/// Una hazaña del catálogo (`game_engine/data/achievements_catalog.dart`).
class AchievementDef {
  const AchievementDef({
    required this.id,
    required this.name,
    required this.category,
    required this.how,
    required this.reward,
    this.counter,
    this.goal = 1,
  });

  final String id;
  final String name;
  final AchievementCategory category;

  /// Cómo se consigue (texto de guía del tooltip).
  final String how;
  final AchievementReward reward;

  /// Las de tiers: el contador (`AchievementCounter`) y la meta.
  final String? counter;
  final int goal;
}

/// Hazañas de la cuenta (JSON `ach`, § 6): ids logrados con su fecha (en
/// segundos) y los contadores. Inmutable.
class AchievementProgress {
  AchievementProgress(
      {Map<String, int> done = const {}, Map<String, int> counters = const {}})
      : done = Map.unmodifiable(done),
        counters = Map.unmodifiable({
          for (final e in counters.entries)
            if (e.value > 0) e.key: e.value,
        });

  static final empty = AchievementProgress();

  /// Versión del catálogo (`v`).
  static const version = 1;

  final Map<String, int> done;
  final Map<String, int> counters;

  bool isDone(String id) => done.containsKey(id);

  int count(String counter) => counters[counter] ?? 0;

  bool get isEmpty => done.isEmpty && counters.isEmpty;

  /// Unión de logradas (la fecha más vieja) y máximo de cada contador:
  /// dos sesiones o dos personajes nunca se pisan (§ 5.1).
  AchievementProgress merge(AchievementProgress o) {
    if (o.isEmpty) return this;
    if (isEmpty) return o;
    final d = {...done};
    for (final e in o.done.entries) {
      final cur = d[e.key];
      if (cur == null || (e.value > 0 && (cur == 0 || e.value < cur))) {
        d[e.key] = e.value;
      }
    }
    final c = {...counters};
    for (final e in o.counters.entries) {
      if (e.value > (c[e.key] ?? 0)) c[e.key] = e.value;
    }
    return AchievementProgress(done: d, counters: c);
  }

  AchievementProgress copyWith(
          {Map<String, int>? done, Map<String, int>? counters}) =>
      AchievementProgress(
          done: done ?? this.done, counters: counters ?? this.counters);

  Map<String, Object?> toJson() => {
        'v': version,
        if (done.isNotEmpty) 'done': done,
        if (counters.isNotEmpty) 'c': counters,
      };

  /// Lectura tolerante: lo que no es un número entero se descarta. Los
  /// ids que ya no existen se conservan (no molestan) y la UI los ignora.
  factory AchievementProgress.fromJson(Object? raw) {
    if (raw is! Map) return AchievementProgress();
    Map<String, int> ints(Object? v, {int min = 0}) => v is Map
        ? {
            for (final e in v.entries)
              if (e.key is String && e.value is num && (e.value as num) >= min)
                e.key as String: (e.value as num).toInt(),
          }
        : const {};
    return AchievementProgress(
        done: ints(raw['done']), counters: ints(raw['c'], min: 1));
  }
}

/// Una hazaña recién lograda y lo que pagó (§ 5.1).
class AchievementUnlock {
  const AchievementUnlock(this.id, this.reward, {this.lost = const {}});
  final String id;
  final AchievementReward reward;

  /// Lo que no entró por la pila 99 (o el tope de pociones) y se perdió.
  final Map<String, int> lost;
}
