import 'dart:math' as math;

import '../data/biomes_catalog.dart';
import '../data/farming_catalog.dart';
import '../data/fishing_catalog.dart';
import '../data/tuning_catalog.dart';
import '../models/player_profile.dart';
import '../models/world_save.dart';
import 'helper_rules.dart';
import 'life_tree_rules.dart';
import 'town_plan.dart';

export '../models/resident.dart';

/// Etapa de un habitante en el pueblo (overworld_biomes.md § 10.3).
enum ResidentStage {
  recienLlegado('Recién llegado'),
  asentado('Asentado'),
  arraigado('Arraigado');

  const ResidentStage(this.label);
  final String label;
}

/// Tipo de paso de una cadena de encargos (§ 10.2).
enum QuestKind {
  recolectar('Recolectar'),
  pescar('Pescar'),
  cultivar('Cultivar'),
  mazmorra('Mazmorra'),
  elite('Élite');

  const QuestKind(this.label);
  final String label;

  /// Se entrega con cosas de la bolsa (los otros los cuenta el anfitrión
  /// al ganar).
  bool get delivered =>
      this == recolectar || this == pescar || this == cultivar;
}

/// Un paso de la cadena de encargos de un habitante.
class QuestStepDef {
  const QuestStepDef(this.kind, this.target, this.n, this.text,
      {this.gold = 0, this.rep = 1, this.reward});
  final QuestKind kind;

  /// Producto, pez, cultivo o zona (según [kind]).
  final String target;
  final int n;
  final String text;
  final int gold;

  /// Relación que suma al cumplirlo.
  final int rep;

  /// Objeto único al final de la cadena ([kResidentRelics]).
  final String? reward;
}

/// Objeto único del final de una cadena (§ 10.2): un recuerdo del
/// habitante. Mientras viva en el pueblo, su beneficio sube un nivel.
class ResidentRelicDef {
  const ResidentRelicDef(this.id, this.name, this.lore);
  final String id;
  final String name;
  final String lore;
}

const kResidentRelics = <String, ResidentRelicDef>{
  'frasco_ilda': ResidentRelicDef('frasco_ilda', 'Frasco de Ilda',
      'Agua del río con hojas que todavía no crecieron.'),
  'placa_velda': ResidentRelicDef('placa_velda', 'Placa de Velda',
      'Un mapa del pasado magitec que se dibuja solo.'),
  'silbato_kael': ResidentRelicDef('silbato_kael', 'Silbato de Kael',
      'Su eco vuelve antes de que lo soples.'),
  'martillo_brann': ResidentRelicDef('martillo_brann', 'Martillo de Brann',
      'Lo movía un mecanismo viejo; ahora lo mueve él.'),
  'reloj_oren': ResidentRelicDef('reloj_oren', 'Reloj de Oren',
      'Marca la hora de algo que ya tiene que pasar.'),
};

/// Cadenas de encargos (§ 10.2), de 3 a 4 pasos por habitante.
const kResidentQuestsDefaults = <String, List<QuestStepDef>>{
  'ilda': [
    QuestStepDef(QuestKind.recolectar, 'hierba_rocio', 3,
        'Traeme tres hierbas de rocío: las de esta mañana, no las de ayer.',
        gold: 60),
    QuestStepDef(QuestKind.pescar, 'trucha_musgo', 1,
        'Una trucha musgosa. Dicen que guarda el agua de un río más viejo.',
        gold: 120),
    QuestStepDef(QuestKind.cultivar, 'helecho_dulce', 2,
        'Plantá helecho dulce en tu huerta y traeme dos.', gold: 150),
    QuestStepDef(QuestKind.mazmorra, '2', 1,
        'Bajá al Bosque Hondo. Algo de allá abajo me cambia las moras.',
        gold: 300, rep: 2, reward: 'frasco_ilda'),
  ],
  'velda': [
    QuestStepDef(QuestKind.recolectar, 'musgo_cobre', 3,
        'El musgo de cobre crece sobre los mecanismos. Traeme tres.',
        gold: 80),
    QuestStepDef(QuestKind.pescar, 'pez_pinon', 1,
        'Un pez piñón del estanque: tiene dientes de engranaje.',
        gold: 160),
    QuestStepDef(QuestKind.mazmorra, '3', 1,
        'Entrá a las Ruinas Cronales. Quiero saber qué orden esperan los '
            'autómatas.',
        gold: 400, rep: 2, reward: 'placa_velda'),
  ],
  'kael': [
    QuestStepDef(QuestKind.recolectar, 'cristal_escarcha', 3,
        'Tres cristales de escarcha. Entrenar con frío enseña rápido.',
        gold: 100),
    QuestStepDef(QuestKind.pescar, 'trucha_hielo', 1,
        'Una trucha de hielo. Hay que tener paciencia: es la lección.',
        gold: 180),
    QuestStepDef(QuestKind.elite, '6', 1,
        'En el Laberinto Temporal hay un guardián que pelea antes de que '
            'llegues. Vencelo.',
        gold: 500, rep: 2, reward: 'silbato_kael'),
  ],
  'brann': [
    QuestStepDef(QuestKind.recolectar, 'raiz_ignea', 3,
        'Raíces ígneas: arden lento, como la fragua que encontré abajo.',
        gold: 140),
    QuestStepDef(QuestKind.cultivar, 'chile_volcan', 2,
        'Dos chiles de volcán de tu huerta. El calor también se cultiva.',
        gold: 220),
    QuestStepDef(QuestKind.mazmorra, '7', 1,
        'Bajá a la Grieta Ígnea. Ese mecanismo viejo sigue andando y '
            'quiero saber por qué.',
        gold: 600, rep: 2, reward: 'martillo_brann'),
  ],
  'oren': [
    QuestStepDef(QuestKind.recolectar, 'polvo_eco', 3,
        'Polvo de eco: lo que deja el futuro cuando pasa.', gold: 180),
    QuestStepDef(QuestKind.pescar, 'pez_eco', 1,
        'Un pez eco. Ya lo pescaste; todavía no lo sabés.', gold: 260),
    QuestStepDef(QuestKind.cultivar, 'trigo_eco', 2,
        'Dos espigas de trigo del eco. Tienen que crecer en tu pueblo.',
        gold: 320),
    QuestStepDef(QuestKind.mazmorra, '9', 1,
        'Entrá al Abismo. Lo que tiene que pasar, pasa allá abajo.',
        gold: 800, rep: 2, reward: 'reloj_oren'),
  ],
};

/// Lo que lee el juego (código + `assets/data/npcs/npcs.json`).
final Map<String, List<QuestStepDef>> kResidentQuests =
    Map.of(kResidentQuestsDefaults);

/// Resultado de entregar un encargo: perfil y pueblo nuevos y el paso de
/// la cadena cumplido (si hubo).
typedef ResidentResult = ({
  PlayerProfile profile,
  TownState town,
  QuestStepDef? done,
});

/// Reglas de los habitantes del pueblo (overworld_biomes.md § 10). Puras;
/// los números en `kTuning[TuningId.town]` (`res*`).
abstract final class ResidentRules {
  static TuningDef get t => tuning(TuningId.town);

  /// Relación suficiente para invitarlo (`resInviteRep`).
  static bool canInvite(int rep) => rep >= t.i('resInviteRep');

  /// Por qué no se puede invitar a [npc] (o `null`).
  static String? cannotInvite(TownState s, String npc) {
    final r = s.resident(npc);
    if (biomeNpc(npc) == null) return 'No existe';
    if (r.invited) return 'Ya vive en el pueblo';
    if (!canInvite(r.rep)) {
      return 'Relación ${r.rep}/${t.i('resInviteRep')}';
    }
    return null;
  }

  /// Etapa por relación (`settledRep`, `rootedRep`).
  static ResidentStage stage(ResidentState r) => r.rep >= t.i('resRootedRep')
      ? ResidentStage.arraigado
      : r.rep >= t.i('resSettledRep')
          ? ResidentStage.asentado
          : ResidentStage.recienLlegado;

  /// Nivel del beneficio: etapa + nivel del edificio − 1, +1 con su
  /// objeto único, −1 si está descontento (nunca debajo de la base, 0).
  /// Sin casa no hay beneficio (−1).
  static int tier(ResidentState r) {
    if (r.house <= 0) return -1;
    var raw = stage(r).index + r.house - 1 + (r.relic ? 1 : 0);
    if (r.unhappy) raw -= 1;
    return raw.clamp(0, t.i('resMaxTier'));
  }

  /// Nivel con la casa un nivel más arriba (o con su primera casa);
  /// `null` si ya no sube.
  static int? nextTier(ResidentState r) {
    if (r.house >= t.i('resMaxHouse')) return null;
    final up = tier(r.copyWith(house: r.house + 1));
    return up > tier(r) ? up : null;
  }

  /// Valor del beneficio permanente del rol en el nivel [tier] (≥ 0).
  static double benefit(NpcRole role, int tier) {
    if (tier < 0) return 0;
    final k = role.name;
    return t.d('res${k}Base') + t.d('res${k}Step') * tier;
  }

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);

  /// "Beneficio: …" con el valor del nivel [tier].
  static String benefitText(BiomeNpcDef n, int tier) =>
      n.benefit.replaceAll('{v}', _fmt(benefit(n.role, tier < 0 ? 0 : tier)));

  /// Beneficio activo del rol [role] en el pueblo [s] (0 = nadie con ese
  /// rol vive en una casa). Lo aplica el anfitrión para toda la sala.
  static double bonus(TownState s, NpcRole role) {
    var best = 0.0;
    for (final r in s.residents.values) {
      if (!r.invited) continue;
      if (biomeNpc(r.npc)?.role != role) continue;
      best = math.max(best, benefit(role, tier(r)));
    }
    return best;
  }

  /// Fracción (0,1 = 10 %) de un beneficio en porcentaje.
  static double frac(TownState s, NpcRole role) => bonus(s, role) / 100;

  /// Descuento de la forja de estadísticas: Brann con casa más el árbol
  /// de Herrería de [p] (roles.md § 6). Lo usan el anfitrión y la UI.
  static double forgeDiscount(PlayerProfile p, TownState s) =>
      (frac(s, NpcRole.forjador) + SmithRules.forgeDiscount(p))
          .clamp(0.0, 0.75)
          .toDouble();

  /// Los habitantes que viven en el pueblo, en el orden de los biomas.
  static List<BiomeNpcDef> living(TownState s) => [
        for (final n in kBiomeNpcs)
          if (s.resident(n.id).invited) n
      ];

  // ---------------- casa ----------------

  /// Costo de poner una CASA (town_editor.md § 3.4): oro y tablas.
  static HelperCost placeCost() => (
        gold: t.i('resHouseGold'),
        mats: {'tabla': t.i('resHouseMat')}..removeWhere((_, v) => v <= 0),
        level: 1,
      );

  /// Producto silvestre del bioma de [n] que pide para subir su casa.
  static String lootOf(BiomeNpcDef n) {
    final lay = biomeLayout(n.biome)!;
    return kForageKinds[lay.forage.first.kind].item;
  }

  /// Costo de subir la casa de [n] al nivel [next]: oro × nivel, tablas
  /// × nivel y botín de su bioma (`resHouseLoot` × nivel).
  static ({HelperCost cost, String loot, int lootN}) investCost(
          BiomeNpcDef n, int next) =>
      (
        cost: (
          gold: houseCost(next),
          mats: {'tabla': t.i('resHouseMat') * next}
            ..removeWhere((_, v) => v <= 0),
          level: 1,
        ),
        loot: lootOf(n),
        lootN: t.i('resHouseLoot') * next,
      );

  /// Costo en oro del nivel [next] del edificio (`houseGold` × nivel).
  static int houseCost(int next) => t.i('resHouseGold') * next;

  /// Cuántos de [crop] (cualquier calidad) tiene [p] en la bolsa.
  static int cropHave(PlayerProfile p, String crop) {
    var n = 0;
    for (final e in p.life.farm.crops.entries) {
      if (parseCropKey(e.key)?.$1.id == crop) n += e.value;
    }
    return n;
  }

  /// [p] sin [n] de [crop] (las de menor calidad primero), o `null`.
  static PlayerProfile? takeCrop(PlayerProfile p, String crop, int n) {
    if (cropHave(p, crop) < n) return null;
    final crops = {...p.life.farm.crops};
    var left = n;
    for (final q in CropQuality.values) {
      if (left <= 0) break;
      final k = cropKey(crop, q);
      final have = crops[k] ?? 0;
      final use = math.min(have, left);
      if (use <= 0) continue;
      left -= use;
      if (have - use <= 0) {
        crops.remove(k);
      } else {
        crops[k] = have - use;
      }
    }
    return p.copyWith(
        life: p.life.copyWith(farm: p.life.farm.copyWith(crops: crops)));
  }

  static PlayerProfile? takeFish(PlayerProfile p, String sp, int n) {
    final have = p.life.count(sp);
    if (have < n) return null;
    final bag = {...p.life.bag};
    if (have - n <= 0) {
      bag.remove(sp);
    } else {
      bag[sp] = have - n;
    }
    return p.copyWith(life: p.life.copyWith(bag: bag));
  }

  /// Por qué no se puede subir la casa de [npc] (o `null`).
  static String? cannotInvest(PlayerProfile p, TownState s, String npc) {
    final n = biomeNpc(npc);
    final h = s.houseOf(npc);
    if (n == null || h == null) return 'Necesita una casa';
    if (h.level >= t.i('resMaxHouse')) return 'Casa al máximo';
    final c = investCost(n, h.level + 1);
    final why = HelperRules.cannotPay(p, c.cost);
    if (why != null) return why;
    final have = cropHave(p, c.loot);
    if (have < c.lootN) {
      return 'Falta ${kCrops[c.loot]?.name ?? c.loot} ($have/${c.lootN})';
    }
    return null;
  }

  /// Sube la casa de [npc] un nivel. Si su pedido era la casa, se cumple.
  static (PlayerProfile, TownState)? invest(
      PlayerProfile p, TownState s, String npc) {
    if (cannotInvest(p, s, npc) != null) return null;
    final n = biomeNpc(npc)!;
    final h = s.houseOf(npc)!;
    final c = investCost(n, h.level + 1);
    var prof = HelperRules.pay(p, c.cost);
    prof = prof == null ? null : takeCrop(prof, c.loot, c.lootN);
    if (prof == null) return null;
    var town = sync(s.withBuild(h.copyWith(level: h.level + 1)));
    final r = town.resident(npc);
    if (r.request == ResidentRequest.casa) {
      town = town.withResident(fulfill(r, s.sky.day));
    }
    return (prof, town);
  }

  /// Copia el nivel de la casa de cada habitante en su estado y saca de
  /// las casas a quien ya no vive en el pueblo.
  static TownState sync(TownState s) {
    bool stray(TownBuild b) =>
        b.kind == BuildKind.casa &&
        b.resident != null &&
        !s.resident(b.resident!).invited;
    final next = s.builds.any(stray)
        ? s.copyWith(builds: [
            for (final b in s.builds)
              stray(b) ? b.copyWith(clearResident: true) : b
          ])
        : s;
    Map<String, ResidentState>? res;
    for (final r in next.residents.values) {
      final lv = next.houseOf(r.npc)?.level ?? 0;
      if (lv == r.house) continue;
      (res ??= {...next.residents})[r.npc] = r.copyWith(house: lv);
    }
    return res == null ? next : next.copyWith(residents: res);
  }

  /// Asigna la casa [houseId] a [npc] (si vivía en otra, se muda; si en
  /// esa vivía otro, queda sin casa).
  static TownState? assign(TownState s, String npc, String houseId) {
    final h = s.build(houseId);
    if (h == null || h.kind != BuildKind.casa) return null;
    if (!s.resident(npc).invited || h.resident == npc) return null;
    final builds = [
      for (final b in s.builds)
        if (b.id == houseId)
          b.copyWith(resident: npc)
        else if (b.kind == BuildKind.casa && b.resident == npc)
          b.copyWith(clearResident: true)
        else
          b
    ];
    return sync(s.copyWith(builds: builds));
  }

  /// Invita a [npc] a vivir en el pueblo.
  static TownState? invite(TownState s, String npc) {
    if (cannotInvite(s, npc) != null) return null;
    final r = s.resident(npc);
    return sync(s.withResident(
        r.copyWith(invited: true, requestDay: math.max(1, s.sky.day))));
  }

  // ---------------- relación ----------------

  /// Lo que [n] acepta de regalo: productos silvestres, cultivos y peces
  /// de su bioma.
  static List<String> giftables(BiomeNpcDef n) {
    final lay = biomeLayout(n.biome);
    if (lay == null) return const [];
    return [
      for (final f in {for (final s in lay.forage) s.kind})
        kForageKinds[f].item,
      ...lay.seeds.keys,
      ...lay.fish,
    ];
  }

  /// Regala uno de [item] a [npc]: +1 de relación una vez por día del
  /// mundo (los demás regalos se aceptan pero no suman). El `bool` dice
  /// si sumó.
  static (PlayerProfile, TownState, bool)? gift(
      PlayerProfile p, TownState s, String npc, String item) {
    final n = biomeNpc(npc);
    if (n == null || !giftables(n).contains(item)) return null;
    final prof =
        kFish.containsKey(item) ? takeFish(p, item, 1) : takeCrop(p, item, 1);
    if (prof == null) return null;
    final r = s.resident(npc);
    final day = math.max(1, s.sky.day);
    final counts = r.giftDay != day;
    return (
      prof,
      s.withResident(counts ? r.copyWith(rep: r.rep + 1, giftDay: day) : r),
      counts
    );
  }

  /// Cuántos tiene [p] de lo que pide el paso [q].
  static int questHave(PlayerProfile p, QuestStepDef q) => switch (q.kind) {
        QuestKind.pescar => p.life.count(q.target),
        QuestKind.recolectar || QuestKind.cultivar => cropHave(p, q.target),
        _ => 0,
      };

  /// Entrega lo que pide el paso actual de la cadena de [npc] (lo que
  /// tenga, hasta completarlo). Paga el oro del paso al cumplirlo.
  static ResidentResult? turnIn(PlayerProfile p, TownState s, String npc) {
    final r = s.resident(npc);
    final q = currentQuest(r);
    if (q == null || !q.kind.delivered) return null;
    final give = math.min(q.n - r.progress, questHave(p, q));
    if (give <= 0) return null;
    final prof = q.kind == QuestKind.pescar
        ? takeFish(p, q.target, give)
        : takeCrop(p, q.target, give);
    if (prof == null) return null;
    final (next, done) = advance(r, q.kind, q.target, give);
    return (
      profile: done == null
          ? prof
          : prof.copyWith(credits: prof.credits + done.gold),
      town: s.withResident(next),
      done: done,
    );
  }

  /// Una mazmorra ganada de la zona [zone] (o un élite vencido en ella,
  /// con [elite]): avanza los pasos que la piden. Devuelve los pasos
  /// cumplidos (para pagar el oro a la party).
  static (TownState, List<(String, QuestStepDef)>) onWin(
      TownState s, int zone, {bool elite = false}) {
    var town = s;
    final out = <(String, QuestStepDef)>[];
    final kind = elite ? QuestKind.elite : QuestKind.mazmorra;
    for (final n in kBiomeNpcs) {
      final r = town.resident(n.id);
      final (next, done) = advance(r, kind, '$zone');
      if (identical(next, r)) continue;
      town = town.withResident(next);
      if (done != null) out.add((n.id, done));
    }
    return (town, out);
  }

  /// Paso actual de la cadena (`null` = terminada o sin cadena).
  static QuestStepDef? currentQuest(ResidentState r) {
    final c = kResidentQuests[r.npc];
    if (c == null || r.quest >= c.length) return null;
    return c[r.quest];
  }

  /// Avanza la cadena con [n] del tipo [kind] / [target]. Devuelve el
  /// nuevo estado y el paso completado (para pagar oro y objeto).
  static (ResidentState, QuestStepDef?) advance(
      ResidentState r, QuestKind kind, String target, [int n = 1]) {
    final q = currentQuest(r);
    if (q == null || q.kind != kind || q.target != target || n <= 0) {
      return (r, null);
    }
    final p = r.progress + n;
    if (p < q.n) return (r.copyWith(progress: p), null);
    return (
      r.copyWith(
          quest: r.quest + 1,
          progress: 0,
          rep: r.rep + q.rep,
          relic: r.relic || q.reward != null),
      q
    );
  }

  // ---------------- pedidos y ánimo ----------------

  /// Un día nuevo del mundo ([day]): si no tiene pedido, pide la próxima
  /// mejora cada `requestEveryDays`; si lo ignoran `unhappyDays`, queda
  /// descontento.
  static ResidentState onDay(ResidentState r, int day) {
    final req = r.request;
    if (req == null) {
      if (day - r.requestDay < t.i('resRequestEveryDays')) return r;
      return r.copyWith(request: nextRequest(r), requestDay: day);
    }
    if (day - r.requestDay >= t.i('resUnhappyDays') && !r.unhappy) {
      return r.copyWith(unhappy: true);
    }
    return r;
  }

  /// [onDay] y [newOrder] para todos los que viven en el pueblo.
  /// [fishLv] / [farmLv]: el oficio más alto de la sala (roles.md § 3).
  static TownState onDayAll(TownState s, int day,
      {int fishLv = 1, int farmLv = 1}) {
    Map<String, ResidentState>? res;
    for (final r in s.residents.values) {
      if (!r.invited) continue;
      final next =
          newOrder(onDay(r, day), day, fishLv: fishLv, farmLv: farmLv);
      if (next == r) continue;
      (res ??= {...s.residents})[r.npc] = next;
    }
    return res == null ? s : s.copyWith(residents: res);
  }

  /// Lo próximo que va a pedir: primero subir la casa, después el resto.
  static ResidentRequest nextRequest(ResidentState r) =>
      r.house < t.i('resMaxHouse')
          ? ResidentRequest.casa
          : ResidentRequest
              .values[1 + r.rep % (ResidentRequest.values.length - 1)];

  /// Por qué el pueblo todavía no tiene lo que pide [npc] (o `null` = ya
  /// está; town_editor.md § 3.4: a menos de `resNearTiles` de su casa).
  /// La casa se cumple sola al subirla.
  static String? requestUnmet(TownState s, String npc) {
    final r = s.resident(npc);
    final req = r.request;
    if (req == null) return 'No pidió nada';
    if (req == ResidentRequest.casa) return 'Se cumple al subir la casa';
    final h = s.houseOf(npc);
    if (h == null) return 'Necesita una casa';
    final hb = h.bounds.inflate(t.i('resNearTiles'));
    bool near(TownRect o) => o.overlaps(hb);
    final ok = switch (req) {
      ResidentRequest.camino => !TownPlan.of(s).unreached.contains(h.id),
      ResidentRequest.faro =>
        s.lights.any((l) => near(TownRect(l.$1, l.$2, 1, 1))),
      ResidentRequest.huerta => s.farms.any((f) => f.parts.any(near)),
      ResidentRequest.muelle => s.lakes.any((f) => f.parts.any(near)),
      ResidentRequest.casa => false,
    };
    return ok ? null : 'Todavía no está';
  }

  /// Pedido cumplido: suma relación, se le pasa el descontento.
  static ResidentState fulfill(ResidentState r, int day) => r.request == null
      ? r
      : r.copyWith(
          clearRequest: true,
          requestDay: day,
          unhappy: false,
          rep: r.rep + t.i('resRequestRep'));

  // ---------------- órdenes de entrega (§ 10.5) ----------------

  /// Si no tiene orden y pasaron `orderEveryDays`, pide algo de su bioma
  /// (determinista por día): 2 a 4 unidades; los cultivos de vez en
  /// cuando de calidad rara o mejor.
  static ResidentState newOrder(ResidentState r, int day,
      {int fishLv = 1, int farmLv = 1}) {
    if (r.order != null) return r;
    if (day - r.orderDay < t.i('orderEveryDays')) return r;
    final n = biomeNpc(r.npc);
    if (n == null) return r;
    final h = day * 31 + r.npc.codeUnits.fold<int>(0, (a, c) => a + c);
    final fish = h % 2 == 0;
    var items = orderPool(n, fish: fish, lv: fish ? fishLv : farmLv);
    if (items.isEmpty) items = giftables(n);
    if (items.isEmpty) return r;
    final item = items[(h ~/ 2) % items.length];
    final isFish = kFish.containsKey(item);
    // Cultivos: calidad rara o mejor; pescados (v0.31.0): un tamaño
    // mínimo (`orderCm`) desde `orderSizeLevel` de Pesca.
    final q = !isFish && farmLv >= t.i('orderQualityLevel') && h % 3 == 0
        ? CropQuality.raro.index
        : isFish && fishLv >= t.i('orderSizeLevel') && h % 3 != 1
            ? 1 + (fishLv ~/ math.max(1, t.i('orderSizeLevel')) + h) % 3
            : 0;
    return r.copyWith(
        order: item,
        orderN: isFish ? 1 + h % 2 : 2 + h % 3,
        orderQ: q,
        orderDay: day);
  }

  /// Lo que puede pedir con el oficio de la sala en [lv] (roles.md § 3):
  /// rarezas hasta `lv / orderRarityLevels`; desde `orderAnyBiomeLevel`,
  /// de cualquier bioma (si no, del suyo).
  static List<String> orderPool(BiomeNpcDef n,
      {required bool fish, required int lv}) {
    final maxR = (lv ~/ math.max(1, t.i('orderRarityLevels')))
        .clamp(0, FishRarity.values.length - 1);
    final any = lv >= t.i('orderAnyBiomeLevel');
    final lays = any ? kBiomeLayouts.values : [biomeLayout(n.biome)!];
    final ids = <String>{
      for (final l in lays)
        if (fish)
          ...l.fish
        else ...[
          for (final f in l.forage) kForageKinds[f.kind].item,
          ...l.seeds.keys,
        ],
    };
    return [
      for (final id in ids)
        if ((fish ? kFish[id]?.rarity : kCrops[id]?.rarity)
            case final rr? when rr.index <= maxR)
          id
    ];
  }

  // ---------------- encargos de forja (roles.md § 4) ----------------

  /// Costo del encargo de forja de Brann: oro por nivel del personaje,
  /// materiales condensados y botín de su bioma.
  static ({HelperCost cost, String loot, int lootN}) commissionCost(
          int charLevel) =>
      (
        cost: (
          gold: t.i('comGold') * charLevel,
          mats: {
            'tabla': t.i('comMat'),
            'fibra': t.i('comMat'),
            'cebo': t.i('comMat'),
          }..removeWhere((_, v) => v <= 0),
          level: 1,
        ),
        loot: lootOf(biomeNpc('brann')!),
        lootN: t.i('comLoot'),
      );

  /// Rareza del arma del encargo (índice de `Rarity`: 1 mágico a 4
  /// legendario): sube con el oficio más alto y la relación con Brann.
  /// Legendaria solo arraigado, con su objeto único y el oficio en
  /// `comLegendLevel`.
  static int commissionRarity(ResidentState brann,
      {required int fishLv, required int farmLv, int smithLv = 1}) {
    final lv = math.max(math.max(fishLv, farmLv), smithLv);
    final score = lv + brann.rep * 2;
    if (brann.relic &&
        stage(brann) == ResidentStage.arraigado &&
        lv >= t.i('comLegendLevel')) {
      return 4;
    }
    if (score >= t.i('comEpicScore')) return 3;
    if (score >= t.i('comRareScore')) return 2;
    return 1;
  }

  /// Nivel de objeto del encargo: el del personaje menos `comIlGap` (las
  /// mejores armas siguen saliendo de las mazmorras).
  static int commissionItemLevel(int charLevel) =>
      math.max(1, charLevel - t.i('comIlGap'));

  /// Por qué [p] no puede pedir el encargo (o `null`): Brann tiene que
  /// vivir en una casa del pueblo.
  static String? cannotCommission(PlayerProfile p, TownState s) {
    final b = s.resident('brann');
    if (!b.invited || b.house <= 0) return 'Brann tiene que vivir en una casa';
    final c = commissionCost(p.level);
    final why = HelperRules.cannotPay(p, c.cost);
    if (why != null) return why;
    final have = cropHave(p, c.loot);
    if (have < c.lootN) {
      return 'Falta ${kCrops[c.loot]?.name ?? c.loot} ($have/${c.lootN})';
    }
    return null;
  }

  /// [p] con el encargo pagado (el arma la genera el motor), o `null`.
  static PlayerProfile? payCommission(PlayerProfile p, TownState s) {
    if (cannotCommission(p, s) != null) return null;
    final c = commissionCost(p.level);
    final paid = HelperRules.pay(p, c.cost);
    return paid == null ? null : takeCrop(paid, c.loot, c.lootN);
  }

  /// Valor en oro de una unidad de [item] (precio de venta).
  static int unitValue(String item) =>
      kFish[item]?.price ?? kCrops[item]?.price ?? 10;

  /// Tamaño mínimo (cm) de un pescado pedido con [q] (1..3), o 0: un
  /// cuarto, la mitad o tres cuartos del rango de la especie.
  static int orderCm(String item, int q) {
    final d = kFish[item];
    if (d == null || q <= 0) return 0;
    return d.minCm + ((d.maxCm - d.minCm) * q / 4).round();
  }

  /// Cuántos tiene [p] de [item] con calidad ≥ [q]. Pescados con tamaño:
  /// la bolsa no guarda tamaños, así que vale el récord del bestiario
  /// (fishing.md § 10): con uno así de grande pescado, cuentan los que
  /// tenga de esa especie.
  static int orderHave(PlayerProfile p, String item, int q) {
    if (kFish.containsKey(item)) {
      final cm = orderCm(item, q);
      if (cm > 0 && (p.life.log[item] ?? 0) < cm) return 0;
      return p.life.count(item);
    }
    var n = 0;
    for (final e in p.life.farm.crops.entries) {
      final c = parseCropKey(e.key);
      if (c != null && c.$1.id == item && c.$2.index >= q) n += e.value;
    }
    return n;
  }

  /// Recompensa de la orden de [r]: XP de personaje (antes del tope
  /// diario), oro, relación y si da un punto de árbol.
  static ({int xp, int gold, int rep, bool point}) orderReward(
      ResidentState r) {
    final o = r.order;
    if (o == null) return (xp: 0, gold: 0, rep: 0, point: false);
    final v = unitValue(o) * r.orderN * (1 + r.orderQ);
    final every = math.max(1, t.i('orderSkillEvery'));
    return (
      xp: (v * t.d('orderXpPerValue')).round(),
      gold: (v * t.d('orderGoldPerValue')).round(),
      rep: t.i('orderRep'),
      point: (r.orders + 1) % every == 0,
    );
  }

  /// Entrega la orden de [npc]. [xpLeft]: lo que le queda a [p] del tope
  /// diario de XP por órdenes. Devuelve perfil (con oro, punto de árbol;
  /// la XP la suma el motor), pueblo y la XP a dar.
  static (PlayerProfile, TownState, int)? deliverOrder(
      PlayerProfile p, TownState s, String npc, int xpLeft) {
    final r = s.resident(npc);
    final o = r.order;
    if (o == null || orderHave(p, o, r.orderQ) < r.orderN) return null;
    PlayerProfile? prof;
    if (kFish.containsKey(o)) {
      prof = takeFish(p, o, r.orderN);
    } else {
      final crops = {...p.life.farm.crops};
      var left = r.orderN;
      for (final q in CropQuality.values) {
        if (q.index < r.orderQ || left <= 0) continue;
        final k = cropKey(o, q);
        final use = math.min(crops[k] ?? 0, left);
        if (use <= 0) continue;
        left -= use;
        crops[k] = crops[k]! - use;
        if (crops[k]! <= 0) crops.remove(k);
      }
      prof = p.copyWith(
          life: p.life.copyWith(farm: p.life.farm.copyWith(crops: crops)));
    }
    if (prof == null) return null;
    final w = orderReward(r);
    prof = prof.copyWith(
        credits: prof.credits + w.gold,
        treeBonus: prof.treeBonus + (w.point ? 1 : 0));
    final day = math.max(1, s.sky.day);
    return (
      prof,
      s.withResident(r.copyWith(
          clearOrder: true,
          orderDay: day,
          orders: r.orders + 1,
          rep: r.rep + w.rep)),
      math.min(w.xp, math.max(0, xpLeft)),
    );
  }

  // ---------------- comercio ----------------

  /// Semillas que vende [n] (§ 9.1) con su beneficio en el nivel [tier]:
  /// la común siempre; la rara en su bioma ([home]) o desde
  /// `resStockRare`; la legendaria del bioma desde `resStockLegend` (al
  /// triple de la rara).
  static Map<String, int> stock(BiomeNpcDef n, int tier, {bool home = false}) {
    final lay = biomeLayout(n.biome);
    final keys = n.seeds.keys.toList();
    final out = <String, int>{};
    if (keys.isNotEmpty) out[keys.first] = n.seeds[keys.first]!;
    if (keys.length > 1 && (home || tier >= t.i('resStockRare'))) {
      out[keys[1]] = n.seeds[keys[1]]!;
    }
    final legend =
        lay?.seeds.keys.where((k) => !n.seeds.containsKey(k)).firstOrNull;
    if (legend != null && tier >= t.i('resStockLegend')) {
      out[legend] = n.seeds.values.fold<int>(0, math.max) * 3;
    }
    return out;
  }

  /// Precio de la semilla [crop] en el pueblo [s] (la vende algún
  /// habitante con casa), o `null`.
  static int? townSeedPrice(TownState s, String crop) {
    for (final n in living(s)) {
      final tr = tier(s.resident(n.id));
      if (tr < 0) continue;
      if (stock(n, tr)[crop] case final p?) return p;
    }
    return null;
  }

  // ---------------- en el pueblo ----------------

  /// Dónde está [npc] en el mapa (px) en el segundo [time] de la sala: de
  /// día camina frente a su casa, ida y vuelta; de noche está adentro
  /// (`null`). Igual en todos (sale del reloj de la sala).
  static (double, double)? position(TownState s, String npc, double time,
      {required bool night}) {
    final h = s.houseOf(npc);
    if (h == null || night) return null;
    final (ox, oy) = s.origin;
    final b = h.bounds;
    final span = (b.w + 1) * 16.0;
    final seed = npc.codeUnits.fold<int>(0, (a, c) => a + c) % 7;
    final k = (time / 6 + seed) % 2;
    final f = k < 1 ? k : 2 - k;
    final x = (b.x + ox) * 16.0 - 8 + span * f;
    final y = (b.bottom + oy) * 16.0 + 8;
    return (x, y);
  }
}
