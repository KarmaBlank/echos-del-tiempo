import 'package:echos_del_tiempo/game_engine/data/affixes_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/weapons_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/game_session.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/session_action.dart';
import 'package:echos_del_tiempo/game_engine/models/session_event.dart';
import 'package:echos_del_tiempo/game_engine/models/upgrade_stat.dart';
import 'package:echos_del_tiempo/game_engine/rules/craft_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/mulberry32.dart';
import 'package:flutter_test/flutter_test.dart';

import 'session_test_helpers.dart';

final _craft = progression.crafting;

/// Guerrero con un arma de cada rareza, créditos y materiales.
PlayerProfile _rich({int credits = 10000, Map<CraftMaterial, int>? mats}) =>
    progression.normalize(PlayerProfile(
      name: 'Ana',
      classId: 'guerrero',
      credits: credits,
      materials: mats ??
          const {
            CraftMaterial.esquirla: 2,
            CraftMaterial.cristal: 1,
            CraftMaterial.prisma: 5,
          },
      items: const [
        ItemInstance(uid: 'c', baseId: 'espada_bronce'),
        ItemInstance(
          uid: 'a',
          baseId: 'espada_ignea',
          rarity: Rarity.raro,
          itemLevel: 12,
          name: 'Eco Voraz',
          affixes: [AffixRoll('feroz', 4, 12), AffixRoll('del_oso', 5, 3)],
        ),
        ItemInstance(
          uid: 'b',
          baseId: 'hacha_rompe',
          rarity: Rarity.magico,
          affixes: [AffixRoll('certero', 5, 3), AffixRoll('del_toro', 5, 4)],
        ),
        ItemInstance(
          uid: 'e',
          baseId: 'arco_corto',
          rarity: Rarity.epico,
          itemLevel: 20,
          name: 'Alba Silente',
          passiveId: 'impetu',
          affixes: [AffixRoll('veloz', 5, 2)],
        ),
        ItemInstance(
          uid: 'f',
          baseId: 'espada_templada',
          rarity: Rarity.epico,
          itemLevel: 20,
          name: 'Ruina Eterna',
          passiveId: 'filoResonante',
        ),
        ItemInstance(
          uid: 'l',
          baseId: 'espada_templada',
          rarity: Rarity.legendario,
          itemLevel: 20,
          uniqueId: 'juramentoAlba',
          passiveId: 'albaImplacable',
          affixes: [AffixRoll('feroz', 0, 25), AffixRoll('certero', 0, 6)],
        ),
        ItemInstance(
          uid: 's',
          baseId: 'maza_escudo_roble',
          rarity: Rarity.magico,
          affixes: [AffixRoll('del_baluarte', 5, 1)],
        ),
      ],
      equipped: 'c',
    ));

ItemInstance _it(PlayerProfile p, String uid) => p.itemByUid(uid)!;

void main() {
  test('el perfil de prueba es válido', () {
    final p = _rich();
    expect(p.items, hasLength(7));
    expect(p.equippedUid, 'c');
    expect(_it(p, 'l').affixes, hasLength(2));
  });

  group('forja', () {
    test('tope total por rareza y 5 por estadística', () {
      var p = _rich();
      for (var i = 0; i < 3; i++) {
        p = _craft.forge(p, 'c', UpgradeStat.pow).profile!;
      }
      final cap = _craft.forge(p, 'c', UpgradeStat.crit);
      expect(cap.ok, isFalse);
      expect(cap.error, 'Tope de forja (3)');
      expect(cap.profile, isNull);
      expect(Rarity.values.map((r) => r.forgeCap), [3, 5, 6, 8, 10]);
    });

    test('costo × rareza y la pasiva sube cada 2 niveles', () {
      final p = _rich();
      final r = _craft.forge(p, 'a', UpgradeStat.pow);
      // round(300 × 0.22 × 1 × 1.5) = 99.
      expect(r.credits, 99);
      expect(r.profile!.credits, p.credits - 99);
      var q = p;
      for (final s in [UpgradeStat.pow, UpgradeStat.crit, UpgradeStat.spd]) {
        q = _craft.forge(q, 'f', s).profile!;
      }
      final f = _it(q, 'f');
      expect(f.forgeLevel, 3);
      expect(f.effectivePassiveLevel, 2);
      expect(progression.derivedStats(q.copyWith(equipped: 'f')).mechanics,
          isNot(contains('wp:filoResonante:2')),
          reason: 'requisitos: no se puede equipar a nivel 1');
      expect(_craft.passiveAt(f, 8), startsWith('Filo Resonante V'));
      expect(_craft.forge(p, 'c', UpgradeStat.def).error, 'No se puede mejorar');
      expect(_craft.forge(p, 's', UpgradeStat.def).ok, isTrue);
    });
  });

  group('fusión libre', () {
    test('trasladar afijo: cupo, tipo, repetido, fijos y protegidas', () {
      final p = _rich();
      final r = _craft.transferAffix(p, 'a', 'b', 0);
      expect(r.ok, isTrue);
      expect(r.after!.affixes.map((x) => x.affixId),
          ['feroz', 'del_oso', 'certero']);
      expect(r.consumed, ['b']);
      expect(r.profile!.itemByUid('b'), isNull);
      // 100 × T5 (1) × Raro (1.5).
      expect(r.credits, 150);
      expect(r.profile!.credits, p.credits - 150);
      // Vista previa = resultado.
      expect(_craft.transferAffix(p, 'a', 'b', 0).profile!.toJson(),
          r.profile!.toJson());

      expect(_craft.transferAffix(p, 'a', 'b', 1).error, isNull);
      expect(_craft.transferAffix(p, 'c', 'b', 0).error,
          startsWith('Sin lugar'), reason: 'Común: 0 mods');
      expect(_craft.transferAffix(p, 'a', 's', 0).error,
          'No sale en este tipo de arma', reason: 'DEF solo en escudos');
      expect(_craft.transferAffix(p, 'a', 'l', 0).error,
          'Mod fijo de un legendario');
      expect(_craft.transferAffix(p, 'a', 'c', 0).error, 'Está equipada');
      expect(_craft.transferAffix(p, 'a', 'a', 0).error, 'Elige otra arma');
      expect(_craft.transferAffix(p, 'a', 'b', 5).error, 'Elige un afijo');
      final dup = p.copyWith(items: [
        for (final i in p.items)
          i.uid == 'b'
              ? i.copyWith(affixes: [const AffixRoll('feroz', 5, 6)])
              : i,
      ]);
      expect(_craft.transferAffix(dup, 'a', 'b', 0).error, 'Ya tiene ese afijo');
      // Lado lleno: un Mágico admite 1 prefijo.
      final mag = _craft.transferAffix(p, 'b', 'a', 0);
      expect(mag.error, startsWith('Sin lugar'));
      expect(_craft.transferAffix(_rich(credits: 10), 'a', 'b', 0).error,
          'Faltan \$140');
    });

    test('arma inicial: la última no se sacrifica', () {
      final p = _rich().copyWith(equipped: 'a');
      expect(_craft.transferSkill(p, 'a', 'c', 'giro').error, 'Arma inicial');
      final two = p.copyWith(items: [
        ...p.items,
        const ItemInstance(uid: 'c2', baseId: 'espada_bronce'),
      ]);
      expect(_craft.transferSkill(two, 'a', 'c', 'giro').ok, isTrue);
    });

    test('trasladar pasiva: solo a Épico y no las únicas', () {
      final p = _rich();
      final r = _craft.transferPassive(p, 'f', 'e');
      expect(r.ok, isTrue);
      expect(r.after!.passiveId, 'impetu');
      expect(r.replaced, 'Filo Resonante');
      expect(r.credits, 600);
      expect(_craft.transferPassive(p, 'a', 'e').error, 'Solo a un arma Épica');
      expect(_craft.transferPassive(p, 'f', 'l').error, 'Pasiva única');
      expect(_craft.transferPassive(p, 'f', 'b').error, 'No tiene pasiva');
    });

    test('trasladar habilidad: cupos por rareza, reemplaza la más vieja', () {
      final p = _rich();
      final r = _craft.transferSkill(p, 'c', 'b', 'sismo');
      expect(r.after!.extraSkills, ['sismo']);
      expect(r.credits, 200, reason: 'Común: la fusión vieja');
      final q = r.profile!;
      final r2 = _craft.transferSkill(q, 'c', 'a', 'ignea');
      expect(r2.after!.extraSkills, ['ignea']);
      expect(r2.replaced, 'Golpe Sísmico');
      // Épico: 2 cupos.
      final e1 = _craft.transferSkill(p, 'f', 'b', 'sismo').profile!;
      final e2 = _craft.transferSkill(e1, 'f', 'a', 'ignea');
      expect(e2.after!.extraSkills, ['sismo', 'ignea']);
      expect(e2.replaced, isNull);
      expect(_craft.transferSkill(p, 'c', 'b', 'nada').error, 'Elige una habilidad');
      expect(progression.weaponSkills(q), ['giro', 'embestida', 'sismo']);
    });

    test('quitar afijo (no los fijos)', () {
      final p = _rich();
      final r = _craft.removeAffix(p, 'a', 0);
      expect(r.after!.affixes.single.affixId, 'del_oso');
      // 50 × T4 (2) × Raro (1.5).
      expect(r.credits, 150);
      expect(_craft.removeAffix(p, 'l', 0).error, 'Mod fijo de un legendario');
    });
  });

  group('materiales', () {
    test('Cristal de Era: vista previa sin azar, después agrega un afijo', () {
      final p = _rich();
      final pv = _craft.addAffix(p, 'a');
      expect(pv.ok, isTrue);
      expect(pv.after, isNull);
      expect(pv.profile, isNull);
      expect(pv.outcomes, isNotEmpty);
      expect(pv.materials, {CraftMaterial.cristal: 1});
      final r = _craft.addAffix(p, 'a', random: mulberry32(3));
      expect(r.after!.affixes, hasLength(3));
      final added = kAffixes[r.after!.affixes.last.affixId]!;
      expect(added.allows('espada'), isTrue);
      expect(r.profile!.material(CraftMaterial.cristal), 0);
      expect(_craft.addAffix(r.profile!, 'a', random: mulberry32(4)).error,
          'Falta Cristal de Era');
      expect(_craft.addAffix(p, 'c').error, 'Un arma Común no lleva afijos');
    });

    test('Esquirla del Eco: valores nuevos dentro del rango', () {
      final p = _rich();
      expect(_craft.reroll(p, 'l').outcomes, ['% ATQ: 20–30', '% crítico: 5–8']);
      for (var seed = 0; seed < 20; seed++) {
        final r = _craft.reroll(p, 'l', random: mulberry32(seed));
        final v = r.after!.affixes;
        expect(v[0].value, inInclusiveRange(20, 30));
        expect(v[1].value, inInclusiveRange(5, 8));
        expect(v.every((a) => a.fixed), isTrue);
        expect(r.profile!.material(CraftMaterial.esquirla), 1);
      }
      expect(_craft.reroll(p, 'c').error, 'No tiene afijos');
    });

    test('Prisma Roto: Común → Mágico → Raro → Épico', () {
      var p = _rich();
      final m = _craft.upgradeRarity(p, 'c', random: mulberry32(1));
      expect(m.after!.rarity, Rarity.magico);
      expect(m.after!.affixes, isNotEmpty);
      expect(m.credits, 100);
      expect(m.profile!.material(CraftMaterial.prisma), 4);
      p = m.profile!;
      final e = _craft.upgradeRarity(p, 'a', random: mulberry32(2));
      expect(e.after!.rarity, Rarity.epico);
      expect(e.after!.affixes.length, greaterThanOrEqualTo(5));
      expect(e.after!.passiveId, isNotNull);
      expect(e.profile!.material(CraftMaterial.prisma), 0);
      expect(_craft.upgradeRarity(p, 'f').error, 'Ya está en la rareza máxima');
      expect(_craft.upgradeRarity(e.profile!, 'b').error, 'Falta Prisma Roto');
      expect(_craft.upgradeRarity(p, 'b').outcomes.first, 'Mágico → Raro');
    });
  });

  group('en la sesión (CraftAction)', () {
    test('se aplica en el lobby con el azar del host; no en el campo', () {
      final e = sessionEngine(fieldFallback: 0.3);
      final s = e.addPlayer(e.create(), 'p0', _rich())!.state;
      final pv = _craft.transferAffix(s.players['p0']!.profile, 'a', 'b', 0);
      final step = e.apply(s, 'p0', const CraftAction(CraftOp.transferAffix, 'a',
          sourceUid: 'b', index: 0))!;
      expect(step.state.players['p0']!.profile.toJson(), pv.profile!.toJson());
      expect(step.events.whereType<CraftedEvent>().single.uid, 'a');
      final r = e.apply(step.state, 'p0', const CraftAction(CraftOp.addAffix, 'a'))!;
      expect(r.state.players['p0']!.profile.itemByUid('a')!.affixes, hasLength(4));
      expect(e.apply(s, 'p0', const CraftAction(CraftOp.transferAffix, 'a')),
          isNull, reason: 'sin arma a sacrificar');
      final f = inField(sessionEngine(), 'm1', profiles: [_rich()]);
      expect(sessionEngine().apply(f, 'p0', const CraftAction(CraftOp.removeAffix, 'a')),
          isNull);
      expect(f.mode, SessionMode.field);
    });

    test('costos documentados', () {
      expect(CraftRules.tierCost(5), 1);
      expect(CraftRules.tierCost(1), 8);
      expect(CraftRules.transferSkillCost(Rarity.comun), 200);
      expect(CraftRules.upgradeRarityCost(Rarity.raro), (4, 800));
      expect(CraftRules.forgeCost(kWeapons['espada_bronce']!, Rarity.comun, 0), 44);
    });
  });
}
