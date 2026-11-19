import 'package:echos_del_tiempo/game_engine/data/ascension_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/skills_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/weapons_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/models/player_profile.dart';
import 'package:echos_del_tiempo/game_engine/models/session_action.dart';
import 'package:echos_del_tiempo/game_engine/models/skill.dart';
import 'package:echos_del_tiempo/game_engine/models/weapon.dart';
import 'package:echos_del_tiempo/game_engine/serialization/action_json.dart';
import 'package:flutter_test/flutter_test.dart';

import 'session_test_helpers.dart';

// Traslado de habilidades v0.5.1 (docs/specs/loot.md § 16.1–16.2).

final _craft = progression.crafting;
final _items = progression.items;

PlayerProfile _p({List<String> meleeExtras = const []}) =>
    progression.normalize(PlayerProfile(
      name: 'Ana',
      classId: 'guerrero',
      credits: 10000,
      items: [
        ItemInstance(uid: 'm', baseId: 'espada_bronce', extraSkills: meleeExtras),
        const ItemInstance(uid: 'm2', baseId: 'espada_bronce'),
        const ItemInstance(uid: 'r', baseId: 'arco_corto'),
        const ItemInstance(uid: 'r2', baseId: 'rifle_aturdidor'),
        const ItemInstance(uid: 'c', baseId: 'baculo_fuego'),
        const ItemInstance(uid: 'c2', baseId: 'baculo_fuego'),
        const ItemInstance(uid: 'd', baseId: 'dagas_cobre'),
        const ItemInstance(
            uid: 'e',
            baseId: 'espada_bronce',
            rarity: Rarity.epico,
            itemLevel: 20,
            name: 'Ruina',
            extraSkills: ['bola', 'tajoGemelo']),
      ],
    ));

void main() {
  group('clasificación', () {
    test('toda habilidad de arma tiene entrega; los kits de ascensión no', () {
      final expected = {
        for (final id in kSkills.keys)
          if (!kAscensionSkills.containsKey(id) &&
              !kEngineSkillIds.contains(id))
            id,
      };
      expect(kSkillDelivery.keys.toSet(), expected);
      for (final id in kAscensionSkills.keys) {
        expect(_items.skillCategory(id), isNull, reason: id);
      }
    });

    test('no físicas = any; físicas = melee o ranged', () {
      for (final e in kSkillDelivery.entries) {
        final phys = kSkills[e.key]!.kind == SkillKind.physical;
        expect(
            e.value == SkillDelivery.any || e.value == SkillDelivery.caster,
            !phys,
            reason: e.key);
      }
    });

    test('coherente con las armas que las dan', () {
      final cats = <String, Set<WeaponCategory>>{};
      for (final w in kWeapons.values) {
        for (final s in w.skillIds) {
          (cats[s] ??= {}).add(kWeaponTypeCategory[w.type]!);
        }
      }
      for (final e in kSkillDelivery.entries) {
        final c = cats[e.key] ?? const <WeaponCategory>{};
        if (e.value == SkillDelivery.ranged) {
          expect(c, contains(WeaponCategory.ranged), reason: e.key);
        }
        if (e.value == SkillDelivery.melee) {
          expect(c, contains(WeaponCategory.melee), reason: e.key);
          expect(c, isNot(contains(WeaponCategory.ranged)), reason: e.key);
        }
      }
      expect(kSkillDelivery['venenosa'], SkillDelivery.ranged,
          reason: 'Flecha Venenosa (arco y dagas) es un disparo');
      expect(kSkillDelivery['dagaSaltarina'], SkillDelivery.melee);
      expect(kSkillDelivery['senalar'], SkillDelivery.any);
    });

    test('todo tipo de arma tiene categoría', () {
      for (final w in kWeapons.values) {
        expect(kWeaponTypeCategory.containsKey(w.type), isTrue, reason: w.type);
      }
      expect(kWeaponTypeCategory['báculo'], WeaponCategory.caster);
      expect(kWeaponTypeCategory['ballesta'], WeaponCategory.ranged);
      expect(kWeaponTypeCategory['maza+escudo'], WeaponCategory.melee);
    });
  });

  group('restricción por arma', () {
    test('canReceiveSkill', () {
      final p = _p();
      final melee = p.itemByUid('m')!,
          ranged = p.itemByUid('r')!,
          caster = p.itemByUid('c')!;
      expect(_items.canReceiveSkill(melee, 'tajoGemelo'), isNull);
      expect(_items.canReceiveSkill(melee, 'aturdir'), 'Solo armas a distancia');
      expect(_items.canReceiveSkill(ranged, 'aturdir'), isNull);
      expect(_items.canReceiveSkill(ranged, 'giro'),
          'Solo armas cuerpo a cuerpo');
      expect(_items.canReceiveSkill(caster, 'giro'),
          'Solo armas cuerpo a cuerpo');
      expect(_items.canReceiveSkill(caster, 'aturdir'),
          'Solo armas a distancia');
      for (final w in [melee, ranged, caster]) {
        expect(_items.canReceiveSkill(w, 'bola'), isNull);
        expect(_items.canReceiveSkill(w, 'curaFocal'), isNull);
        expect(_items.canReceiveSkill(w, 'inspirar'), isNull);
      }
      expect(_items.canReceiveSkill(melee, 'gritoGuerra'),
          'Elige una habilidad', reason: 'kit de ascensión');
    });

    test('transferSkill valida la entrega', () {
      final p = _p();
      expect(_craft.transferSkill(p, 'm', 'r2', 'aturdir').error,
          'Solo armas a distancia');
      expect(_craft.transferSkill(p, 'r', 'd', 'tajoGemelo').error,
          'Solo armas cuerpo a cuerpo');
      expect(_craft.transferSkill(p, 'c', 'm2', 'giro').error,
          'Solo armas cuerpo a cuerpo');
      expect(_craft.transferSkill(p, 'c', 'r2', 'aturdir').error,
          'Solo armas a distancia');
      expect(_craft.transferSkill(p, 'm', 'd', 'tajoGemelo').ok, isTrue);
      expect(_craft.transferSkill(p, 'r', 'r2', 'aturdir').ok, isTrue);
      expect(_craft.transferSkill(p, 'm', 'c2', 'bola').ok, isTrue);
      expect(_craft.transferSkill(p, 'r', 'c2', 'bola').ok, isTrue);
      expect(_craft.transferSkill(p, 'c', 'c2', 'llamarada').ok, isTrue);
    });

    test('sanitize conserva las trasladadas viejas que hoy no se podrían', () {
      const legacy = ItemInstance(
          uid: 'x', baseId: 'baculo_fuego', extraSkills: ['giro']);
      expect(_items.sanitize(legacy)!.extraSkills, ['giro']);
      expect(_items.skillsOf(_items.sanitize(legacy)!),
          ['bola', 'llamarada', 'giro']);
    });
  });

  group('elegir el reemplazo', () {
    test('cupos llenos: sin elegir falla; elegido reemplaza ese', () {
      final p = _p(meleeExtras: ['bola']);
      final m = p.itemByUid('m')!;
      expect(_items.replaceableSkills(m), ['bola']);
      expect(_items.needsReplaceChoice(m, 'tajoGemelo'), isTrue);
      expect(_items.needsReplaceChoice(m, 'bola'), isFalse,
          reason: 'volver a traer la misma no ocupa cupo');
      expect(_craft.transferSkill(p, 'm', 'd', 'tajoGemelo').error,
          'Elegí qué habilidad reemplazar');
      final r = _craft.transferSkill(p, 'm', 'd', 'tajoGemelo',
          replaceSkillId: 'bola');
      expect(r.ok, isTrue);
      expect(r.after!.extraSkills, ['tajoGemelo']);
      expect(r.replaced, 'Bola de Fuego');
      expect(r.replacedSkillId, 'bola');
      expect(r.consumed, ['d']);
    });

    test('Épico: elige cuál de las dos', () {
      final p = _p();
      final r = _craft.transferSkill(p, 'e', 'm2', 'giro',
          replaceSkillId: 'tajoGemelo');
      expect(r.after!.extraSkills, ['bola', 'giro']);
      expect(r.replacedSkillId, 'tajoGemelo');
      final r2 =
          _craft.transferSkill(p, 'e', 'm2', 'giro', replaceSkillId: 'bola');
      expect(r2.after!.extraSkills, ['tajoGemelo', 'giro']);
    });

    test('no se reemplaza una base ni una que no tiene', () {
      final p = _p(meleeExtras: ['bola']);
      expect(
          _craft
              .transferSkill(p, 'm', 'd', 'tajoGemelo', replaceSkillId: 'giro')
              .error,
          'Las habilidades base no se reemplazan');
      expect(
          _craft
              .transferSkill(p, 'm', 'd', 'tajoGemelo', replaceSkillId: 'nada')
              .error,
          'No tiene esa habilidad');
    });

    test('con cupo libre no hace falta elegir', () {
      final p = _p();
      final r = _craft.transferSkill(p, 'm', 'd', 'tajoGemelo');
      expect(r.after!.extraSkills, ['tajoGemelo']);
      expect(r.replaced, isNull);
      expect(r.replacedSkillId, isNull);
    });

    test('apply y CraftAction pasan replaceSkillId', () {
      final p = _p(meleeExtras: ['bola']);
      final r = _craft.apply(p, CraftOp.transferSkill, 'm',
          sourceUid: 'd', skillId: 'tajoGemelo', replaceSkillId: 'bola');
      expect(r.after!.extraSkills, ['tajoGemelo']);
    });

    test('serialización: rep es aditivo y hace ida y vuelta', () {
      const a = CraftAction(CraftOp.transferSkill, 'm',
          sourceUid: 'd', skillId: 'tajoGemelo', replaceSkillId: 'bola');
      final j = ActionJson.toJson(a);
      expect(j['rep'], 'bola');
      final back = ActionJson.fromJson(j) as CraftAction;
      expect(back.replaceSkillId, 'bola');
      expect(ActionJson.toJson(back), j);
      const old = CraftAction(CraftOp.transferSkill, 'm',
          sourceUid: 'd', skillId: 'tajoGemelo');
      expect(ActionJson.toJson(old).containsKey('rep'), isFalse);
      expect((ActionJson.fromJson(ActionJson.toJson(old)) as CraftAction)
          .replaceSkillId, isNull);
    });
  });
}
