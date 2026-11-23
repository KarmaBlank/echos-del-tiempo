import 'dart:math' as math;

import '../data/biomes_catalog.dart';
import '../data/fishing_catalog.dart';
import '../data/npc_talk_catalog.dart';
import '../models/player_profile.dart';
import '../models/world_save.dart';
import 'resident_rules.dart';

/// Un tema de HABLAR con lo que hace falta para verlo.
typedef TalkProgress = ({int talks, int orders, int rep});

/// Mercancía del arraigado: pez, precio por unidad y si es la novedad.
typedef NativeGood = ({String species, int price, bool fresh});

/// Reglas puras de la charla y de los arraigados (overworld_biomes.md
/// § 12). El anfitrión valida; la UI usa lo mismo para explicar.
abstract final class NpcTalkRules {
  /// Amistad que da cada charla contada (una por día del mundo).
  static const talkRep = 1;

  /// Amistad que da cada pedido del día cumplido.
  static const orderRep = 2;

  /// Para invitar a un arraigado: amistad y pedidos cumplidos.
  static const inviteRep = 8;
  static const inviteOrders = 3;

  /// Regalo único del arraigado (algo mejor que el objeto único de un
  /// habitante que se muda): oro, XP de Pesca, un punto de árbol y su
  /// favor (sus pedidos pagan [favorGold] veces el oro desde entonces).
  static const giftGold = 400;
  static const giftFishXp = 150;
  static const giftPoints = 1;
  static const favorGold = 1.25;

  /// Cada cuántos días del mundo trae una novedad a su puesto.
  static const freshEvery = 3;

  /// Compra: precio del pez × [buyMul]; venta: × [sellMul] (mejor que
  /// vender en el pueblo).
  static const buyMul = 3;
  static const sellMul = 1.5;

  // ---------------- charla ----------------

  /// Cuenta una charla con [npc] en [day] (una por día). `null` si ya se
  /// contó hoy o no existe.
  static TownState? talk(TownState s, String npc, int day) {
    if (npcTalk(npc) == null) return null;
    final b = s.bond(npc);
    if (b.talkDay >= day) return null;
    return s.withBond(b.copyWith(
        talks: b.talks + 1,
        talkDay: day,
        rep: npcRooted(npc) ? b.rep + talkRep : b.rep));
  }

  /// Lo que lleva [npc] para abrir temas: charlas, pedidos y relación.
  static TalkProgress progress(TownState s, String npc) {
    final b = s.bond(npc);
    if (npcRooted(npc)) return (talks: b.talks, orders: b.orders, rep: b.rep);
    final r = s.resident(npc);
    return (talks: b.talks, orders: r.orders + r.quest, rep: r.rep);
  }

  static bool open(TalkTopic t, TalkProgress g, {required bool inTown}) =>
      g.talks >= t.talks &&
      g.orders >= t.orders &&
      g.rep >= t.rep &&
      switch (t.where) {
        TalkWhere.any => true,
        TalkWhere.biome => !inTown,
        TalkWhere.town => inTown,
      };

  /// Temas abiertos de [npc] (en orden).
  static List<TalkTopic> topics(TownState s, String npc,
      {required bool inTown}) {
    final d = npcTalk(npc);
    if (d == null) return const [];
    final g = progress(s, npc);
    return [
      for (final t in d.topics)
        if (open(t, g, inTown: inTown)) t
    ];
  }

  /// Cuántos temas faltan abrir (para la pista "Hay más para hablar").
  static int locked(TownState s, String npc, {required bool inTown}) {
    final d = npcTalk(npc);
    if (d == null) return 0;
    final all = d.topics.where((t) => switch (t.where) {
          TalkWhere.any => true,
          TalkWhere.biome => !inTown,
          TalkWhere.town => inTown,
        });
    return all.length - topics(s, npc, inTown: inTown).length;
  }

  /// Un saludo de [npc] elegido con [rng].
  static String greeting(String npc, math.Random rng,
      {List<String> extra = const []}) {
    final pool = [...?npcTalk(npc)?.greet, ...extra];
    return pool.isEmpty ? '…' : pool[rng.nextInt(pool.length)];
  }

  // ---------------- arraigados ----------------

  /// Suma un pedido cumplido al arraigado de [biome].
  static TownState onOrder(TownState s, String biome) {
    final id = nativeId(biome);
    if (!npcRooted(id)) return s;
    final b = s.bond(id);
    return s.withBond(b.copyWith(orders: b.orders + 1, rep: b.rep + orderRep));
  }

  /// ¿Ya le hiciste la invitación (y te dio su regalo)?
  static bool declined(TownState s, String biome) =>
      s.bond(nativeId(biome)).declined;

  /// Por qué todavía no se lo puede invitar (o `null`). La opción no se
  /// muestra mientras haya motivo.
  static String? cannotInvite(TownState s, String biome) {
    final id = nativeId(biome);
    if (!npcRooted(id)) return 'No vive en un bioma';
    final b = s.bond(id);
    if (b.declined) return 'Ya te respondió';
    if (b.rep < inviteRep) return 'Amistad ${b.rep}/$inviteRep';
    if (b.orders < inviteOrders) {
      return 'Pedidos cumplidos ${b.orders}/$inviteOrders';
    }
    return null;
  }

  /// Invitar: dice que no y le da a [p] su regalo único.
  static (PlayerProfile, TownState)? invite(
      PlayerProfile p, TownState s, String biome) {
    if (cannotInvite(s, biome) != null) return null;
    final id = nativeId(biome);
    return (
      p.copyWith(
          credits: p.credits + giftGold,
          treeBonus: p.treeBonus + giftPoints,
          life: p.life.copyWith(fishXp: p.life.fishXp + giftFishXp)),
      s.withBond(s.bond(id).copyWith(declined: true)),
    );
  }

  /// Puesto del arraigado de [biome] en [day] (solo después de la
  /// invitación): los peces comunes de su lago y, cada [freshEvery] días,
  /// una novedad (el más raro).
  static List<NativeGood> stock(TownState s, String biome, int day) {
    if (!declined(s, biome)) return const [];
    final lay = biomeLayout(biome);
    if (lay == null) return const [];
    final fish = [
      for (final id in lay.fish)
        if (kFish[id] case final f?) f
    ]..sort((a, b) => a.rarity.index.compareTo(b.rarity.index));
    if (fish.isEmpty) return const [];
    final common = fish.where((f) => f.rarity == fish.first.rarity).toList();
    final rare = fish.last;
    return [
      for (final f in common)
        if (f.id != rare.id || day % freshEvery != 0)
          (species: f.id, price: f.price * buyMul, fresh: false),
      if (day % freshEvery == 0)
        (species: rare.id, price: rare.price * buyMul, fresh: true),
    ];
  }

  /// Lo que le compra: peces de su lago, a [sellMul] del precio.
  static int? sellPrice(String biome, String species) {
    final f = kFish[species];
    final lay = biomeLayout(biome);
    if (f == null || lay == null || !lay.fish.contains(species)) return null;
    return (f.price * sellMul).round();
  }

  /// Comprar ([buy]) o vender [n] de [species] al arraigado de [biome].
  static PlayerProfile? trade(PlayerProfile p, TownState s, String biome,
      String species, int n, int day,
      {required bool buy}) {
    if (n <= 0 || !declined(s, biome)) return null;
    if (buy) {
      final g =
          stock(s, biome, day).where((g) => g.species == species).firstOrNull;
      if (g == null) return null;
      final cost = g.price * n;
      if (p.credits < cost) return null;
      return p.copyWith(
          credits: p.credits - cost,
          life: p.life.copyWith(
              bag: {...p.life.bag, species: p.life.count(species) + n}));
    }
    final pr = sellPrice(biome, species);
    if (pr == null) return null;
    final t = ResidentRules.takeFish(p, species, n);
    if (t == null) return null;
    return t.copyWith(credits: t.credits + pr * n);
  }
}
