import 'package:echos_del_tiempo/game_engine/data/fishing_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/tuning_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/town_layout.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/models/life_skills.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/session_action.dart';
import 'package:echos_del_tiempo/game_engine/models/session_event.dart';
import 'package:echos_del_tiempo/game_engine/models/world_save.dart';
import 'package:echos_del_tiempo/game_engine/rules/fishing_minigame.dart';
import 'package:echos_del_tiempo/game_engine/rules/fishing_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/session_engine.dart';
import 'package:echos_del_tiempo/game_engine/rules/world_rules.dart';
import 'package:echos_del_tiempo/game_engine/serialization/action_json.dart';
import 'package:echos_del_tiempo/game_engine/serialization/event_json.dart';
import 'package:flutter_test/flutter_test.dart';

import 'session_test_helpers.dart';

/// Pesca y agropecuario (docs/specs/fishing.md).
PlayerProfile _withFish(Map<String, int> bag, {int credits = 0}) =>
    newProfile('Ana', 'guerrero').copyWith(
        credits: credits, life: LifeSkills(bag: bag));

void main() {
  // Sin botín del agua: estos tests miran solo los peces (fishing.md § 8).
  setUp(() => kTuning[TuningId.fishing] = TuningDef('Pesca', {
        ...kTuningDefaults[TuningId.fishing]!.values,
        'lootChance': 0,
        'lootPityAfter': 0,
      }));
  tearDown(
      () => kTuning[TuningId.fishing] = kTuningDefaults[TuningId.fishing]!);
  group('reglas', () {
    test('rareza por pesos; auto-pesca nunca legendaria; pity', () {
      expect(FishingRules.rollRarity(0), FishRarity.comun);
      expect(FishingRules.rollRarity(0.9999), FishRarity.legendario);
      expect(FishingRules.rollRarity(0.9999, auto: true), FishRarity.epico);
      for (var i = 0; i < 100; i++) {
        expect(FishingRules.rollRarity(i / 100, auto: true),
            isNot(FishRarity.legendario));
      }
      expect(FishingRules.rollRarity(0, pity: 200), FishRarity.legendario);
      expect(FishingRules.rollRarity(0, pity: 200, auto: true),
          FishRarity.comun);
      // El bonus de rareza corre la tirada hacia arriba.
      expect(FishingRules.rollRarity(0.6), FishRarity.comun);
      expect(FishingRules.rollRarity(0.6, rareBonus: 1), isNot(FishRarity.comun));
    });

    test('roll: especie del lago y tamaño en rango', () {
      final r = rolls([0.0, 0.0, 0.5]);
      final c = FishingRules.roll(r, kTownLakeDefault);
      expect(c.rarity, FishRarity.comun);
      expect(c.sizeCm, inInclusiveRange(c.def.minCm, c.def.maxCm));
      // Lago sin épicos: baja a raro.
      final c2 = FishingRules.roll(
          rolls([0.95, 0, 0]), ['mojarra_claro', 'trucha_cobre']);
      expect(c2.species, 'trucha_cobre');
    });

    test('cañas: efectividad con piso 0.4 y curva 1.5', () {
      expect(FishingRules.effectiveness(1, 22), closeTo(0.4 + 0.6 * 0.0097, 0.01));
      expect(FishingRules.effectiveness(22, 22), 1);
      expect(FishingRules.effectiveness(30, 22), 1);
      expect(FishingRules.effectiveness(11, 22),
          closeTo(0.4 + 0.6 * 0.35355, 0.001));
      final p = newProfile('Ana', 'guerrero').copyWith(
          life: LifeSkills(rods: const ['cana_eco'], rod: 'cana_eco'));
      final b = FishingRules.rodBonus(p);
      expect(b.rare, lessThan(0.8 * 0.45));
      expect(b.rare, greaterThan(0.8 * 0.4 - 1e-9));
    });

    test('XP y nivel; XP por rareza y tamaño; auto reducida', () {
      expect(FishingRules.levelFor(0), 1);
      expect(FishingRules.levelFor(FishingRules.xpNeed(1)), 2);
      expect(FishingRules.levelFor(1 << 30), FishingRules.maxLevel);
      const big = FishCatch('carpa_musgo', 45), small = FishCatch('carpa_musgo', 20);
      expect(FishingRules.fishXp(big), greaterThan(FishingRules.fishXp(small)));
      expect(FishingRules.fishXp(const FishCatch('carpa_manana', 110)),
          greaterThan(FishingRules.fishXp(big) * 10));
      expect(FishingRules.fishXp(big, auto: true),
          lessThan(FishingRules.fishXp(big)));
      expect(FishingRules.charXp(const FishCatch('pez_reloj', 50)), 30);
    });

    test('precios y venta en oro, materiales y Vender todo', () {
      final p = _withFish({'carpa_musgo': 2, 'trucha_cobre': 1, 'pez_reloj': 1});
      final one = FishingRules.sell(p, species: 'carpa_musgo')!;
      expect(one.credits, 36);
      expect(one.profile.life.count('carpa_musgo'), 0);
      final all = FishingRules.sell(p)!;
      expect(all.sold, 3);
      expect(all.credits, 36 + 45);
      expect(all.profile.life.count('pez_reloj'), 1, reason: 'sin legendarios');
      final mats = FishingRules.sell(p, materials: true)!;
      // 81 × 1.2 = 97 → 3 Esquirlas (75) + 22 de oro.
      expect(mats.esquirlas, 3);
      expect(mats.credits, 22);
      expect(mats.profile.material(CraftMaterial.esquirla), 3);
      expect(FishingRules.sell(_withFish({})), isNull);
    });

    test('canje de legendario y compra / equipo de cañas', () {
      final p = _withFish({'pez_reloj': 1, 'carpa_musgo': 1}, credits: 500);
      final x = FishingRules.exchangeLegendary(p, 'pez_reloj')!;
      expect(x.material(CraftMaterial.cristal), 3);
      expect(x.material(CraftMaterial.prisma), 1);
      expect(x.life.count('pez_reloj'), 0);
      expect(FishingRules.exchangeLegendary(p, 'carpa_musgo'), isNull);
      final b = FishingRules.buyRod(p, 'cana_roble')!;
      expect(b.credits, 100);
      expect(FishingRules.buyRod(b, 'cana_roble'), isNull);
      expect(FishingRules.buyRod(p, 'cana_runica'), isNull, reason: 'sin oro');
      expect(FishingRules.equipRod(b, 'cana_roble')!.life.rod, 'cana_roble');
      expect(FishingRules.equipRod(p, 'cana_roble'), isNull);
    });

    test('migración: perfil viejo recibe la caña de rama', () {
      final json = newProfile('Ana', 'guerrero').toJson()..remove('life');
      final p = PlayerProfile.fromJson(json);
      expect(p.life.rods, [kStarterRod]);
      expect(p.life.rod, kStarterRod);
      final back = PlayerProfile.fromJson(
          p.copyWith(life: p.life.addFish('carpa_musgo', 3)).toJson());
      expect(back.life.count('carpa_musgo'), 3);
      expect(progression.normalize(back).life.count('carpa_musgo'), 3);
      // Ids desconocidos se descartan.
      expect(LifeSkills.fromJson({'rods': ['x'], 'rod': 'x', 'bag': {'x': 2}}).rod,
          kStarterRod);
    });

    test('lago del mundo: zona 1 por defecto, guardado si se cambia', () {
      expect(kTownLakeDefault, isNotEmpty);
      expect(kTownLakeDefault.every((id) => kFish[id]!.biome == 'zona1'), isTrue);
      expect(TownState.fromJson(const TownState().toJson()).lake, isNull);
      expect(TownState.fromJson(const TownState(lake: ['carpa_musgo']).toJson()).lake,
          ['carpa_musgo']);
    });
  });

  group('minijuego', () {
    FishingMinigame game() => FishingMinigame(rolls(const [], fallback: 0.5));

    void run(FishingMinigame g, double s, {bool Function()? hold}) {
      for (var t = 0.0; t < s; t += 0.02) {
        if (g.phase == FishPhase.won || g.phase == FishPhase.lost) {
          if (hold != null) return;
        }
        if (hold != null) hold() ? g.press() : g.release();
        g.tick(0.02);
      }
    }

    test('carga, vuelo, espera y picada; tirar antes la pierde', () {
      final g = game()..press();
      run(g, 0.6);
      expect(g.phase, FishPhase.charging);
      expect(g.power, closeTo(0.5, 0.05));
      g.release();
      run(g, 0.6);
      expect(g.phase, FishPhase.waiting);
      g.press();
      expect(g.phase, FishPhase.lost);
    });

    FishingMinigame toBite() {
      final g = game()..press();
      run(g, 0.3);
      g.release();
      run(g, 0.6);
      run(g, g.biteAt - g.phaseTime + 0.03);
      expect(g.phase, FishPhase.bite);
      return g;
    }

    test('la picada se va si no se reacciona', () {
      final g = toBite();
      run(g, 1.3);
      expect(g.phase, FishPhase.lost);
    });

    test('barra: siguiendo al pez se saca; soltando se escapa', () {
      var g = toBite()..press();
      expect(g.phase, FishPhase.hooking);
      g.release();
      g.hook(const FishCatch('carpa_musgo', 30));
      expect(g.phase, FishPhase.reel);
      run(g, 40,
          hold: () => g.zonePos + g.zoneSize / 2 < g.fishPos || g.zoneVel < -0.4);
      expect(g.phase, FishPhase.won);
      expect(g.reelTime, inInclusiveRange(6, 30));
      g = toBite()..press();
      g.release();
      g.hook(const FishCatch('pez_reloj', 50));
      g.fishPos = 0.9;
      run(g, 40, hold: () => false);
      expect(g.phase, FishPhase.lost);
    });

    test('una caña mejor ensancha la zona y acorta la espera', () {
      final a = FishingMinigame(() => 0.5);
      final b = FishingMinigame(() => 0.5, zoneBonus: 0.5, biteBonus: 0.45);
      expect(b.zoneSize, greaterThan(a.zoneSize));
      expect(FishingRules.biteDelay(0.5, 0.45),
          lessThan(FishingRules.biteDelay(0.5, 0)));
    });
  });

  group('sala (anfitrión valida)', () {
    final spot = TownLayout.fishingSpots.first;
    final x = (spot.$1 + 1) * 16.0 + 4, y = (spot.$2 + 0.5) * 16.0;

    GameSession room(SessionEngine e) {
      var s = e.addPlayer(e.create(), 'p0', newProfile('Ana', 'guerrero'))!.state;
      expect(WorldRules.townSpot(x, y), TownSpot.fishing);
      return moveTo(e, s, 'p0', x, y);
    }

    test('picada → pez del host; resultado otorga y avisa', () {
      final e = sessionEngine(fieldRolls: [0.0, 0.0, 0.5]);
      var s = room(e);
      final bite = e.apply(s, 'p0', const FishBiteAction(0.5))!;
      final ev = bite.events.whereType<FishBiteEvent>().single;
      expect(ev.species, isIn(kTownLakeDefault));
      s = bite.state;
      // Muy rápido: el host lo rechaza.
      expect(e.apply(s, 'p0', const FishResultAction(true)), isNull);
      s = wait(e, s, 2);
      final done = e.apply(s, 'p0', const FishResultAction(true))!;
      final p = done.state.players['p0']!.profile;
      expect(p.life.count(ev.species), 1);
      expect(p.life.fishXp, greaterThan(0));
      expect(p.xp, greaterThan(0));
      expect(done.events.whereType<FishCaughtEvent>().single.sizeCm, ev.sizeCm);
      expect(
          done.events.whereType<SystemMessageEvent>().any((m) => m.text.contains('pescó')),
          isTrue);
      // Sin picada pendiente no hay resultado.
      expect(e.apply(done.state, 'p0', const FishResultAction(true)), isNull);
    });

    test('lejos del lago, lances seguidos y Travesía: rechazados', () {
      final e = sessionEngine();
      var s = e.addPlayer(e.create(), 'p0', newProfile('Ana', 'guerrero'))!.state;
      expect(e.apply(s, 'p0', const FishBiteAction(1)), isNull);
      s = room(e);
      s = act(e, s, 'p0', const FishBiteAction(1));
      s = act(e, s, 'p0', const FishResultAction(false));
      expect(e.apply(s, 'p0', const FishBiteAction(1)), isNull);
      s = wait(e, s, 2.1);
      expect(e.apply(s, 'p0', const FishBiteAction(1)), isNotNull);
    });

    test('auto-pesca: sin legendarios, con espera; tope de XP de personaje', () {
      final e = sessionEngine(fieldFallback: 0.99999);
      var s = room(e);
      final step = e.apply(s, 'p0', const AutoFishAction())!;
      final caught = step.events.whereType<FishCaughtEvent>().toList();
      expect(caught, hasLength(3));
      expect(caught.every((c) => c.auto && kFish[c.species]!.rarity != FishRarity.legendario),
          isTrue);
      s = step.state;
      expect(e.apply(s, 'p0', const AutoFishAction()), isNull);
      s = wait(e, s, 31);
      for (var i = 0; i < 20; i++) {
        s = act(e, s, 'p0', const AutoFishAction());
        s = wait(e, s, 31);
      }
      expect(s.players['p0']!.profile.xp, lessThanOrEqualTo(60));
    });

    test('agropecuario en la sala: vender, canjear, cañas', () {
      final e = sessionEngine();
      var s = e.addPlayer(e.create(), 'p0',
          _withFish({'carpa_musgo': 2, 'pez_reloj': 1}, credits: 400))!.state;
      s = act(e, s, 'p0', const SellFishAction(materials: true));
      s = act(e, s, 'p0', const ExchangeFishAction('pez_reloj'));
      s = act(e, s, 'p0', const BuyRodAction('cana_roble'));
      s = act(e, s, 'p0', const EquipRodAction('cana_roble'));
      final p = s.players['p0']!.profile;
      expect(p.life.bagTotal, 0);
      expect(p.life.rod, 'cana_roble');
      expect(p.material(CraftMaterial.cristal), 3);
    });

    test('JSON de acciones y eventos', () {
      for (final a in const <SessionAction>[
        FishBiteAction(0.4),
        FishResultAction(true),
        AutoFishAction(),
        SellFishAction(species: 'carpa_musgo', materials: true),
        SellFishAction(),
        ExchangeFishAction('pez_reloj'),
        BuyRodAction('cana_roble'),
        EquipRodAction('cana_roble'),
      ]) {
        expect(ActionJson.toJson(ActionJson.fromJson(ActionJson.toJson(a))),
            ActionJson.toJson(a));
      }
      const ej = EventJson();
      final b = ej.fromJson(ej.toJson(const FishCaughtEvent('p0', 'pez_reloj', 50, auto: true)))
          as FishCaughtEvent;
      expect((b.species, b.sizeCm, b.auto), ('pez_reloj', 50, true));
    });
  });
}
