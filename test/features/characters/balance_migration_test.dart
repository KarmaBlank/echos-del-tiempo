import 'dart:convert';
import 'dart:io';

import 'package:echos_del_tiempo/features/characters/data/account_store.dart';
import 'package:echos_del_tiempo/features/characters/domain/account.dart';
import 'package:echos_del_tiempo/game_engine/data/game_catalog.dart';
import 'package:echos_del_tiempo/game_engine/data/uniques_catalog.dart';
import 'package:echos_del_tiempo/game_engine/models/item.dart';
import 'package:echos_del_tiempo/game_engine/models/weapon.dart';
import 'package:echos_del_tiempo/game_engine/rules/balance_migration.dart';
import 'package:echos_del_tiempo/game_engine/rules/craft_rules.dart';
import 'package:echos_del_tiempo/game_engine/rules/item_rules.dart';
import 'package:flutter_test/flutter_test.dart';

/// Cuenta "v0.8.6" inventada (sin `bv`): nunca datos reales del jugador.
Map<String, Object?> _v086Account() => {
      'v': 1,
      'sel': 'c1',
      'seq': 1,
      'chars': [
        {
          'id': 'c1',
          'p': {
            'pv': 3,
            'name': 'Prueba',
            'cls': 'guerrero',
            'lvl': 8,
            'xp': 120,
            'cr': 1000,
            'pts': 0,
            'items': [
              // Legendaria de nivel 5 con los mods fijos del catálogo
              // (nivel alto) y forja +10.
              {
                'u': 'i1',
                'b': 'espada_templada',
                'r': 'legendario',
                'il': 5,
                'q': 'juramentoAlba',
                'p': 'albaImplacable',
                'a': [
                  ['feroz', 0, 28],
                  ['certero', 0, 7],
                ],
                'f': {'pow': 5, 'crit': 5},
              },
              // Épica con fusiones inválidas: una del motor, una que no
              // existe y una válida.
              {
                'u': 'i2',
                'b': 'espada_ignea',
                'r': 'epico',
                'il': 5,
                's': ['brasaEco', 'noExiste', 'chispa'],
              },
            ],
            'eq': 'i1',
            'mats': {'esquirla': 4},
            'tree': ['nodoX'],
            'tv': 5,
            'zu': 2,
          },
        },
      ],
      'stash': {
        'cells': [
          {
            'i': 0,
            'it': {
              'u': 's1',
              'b': 'espada_templada',
              'r': 'legendario',
              'il': 5,
              'q': 'juramentoAlba',
              'p': 'albaImplacable',
              'a': [
                ['feroz', 0, 30],
              ],
              'f': {'pow': 4},
            },
          },
        ],
      },
    };

void main() {
  const craft = CraftRules();
  final w = GameCatalog.standard.weapons['espada_templada']!;
  final feroz = kUniques['juramentoAlba']!.fixed.first;
  final ferozMax = ItemRules.fixedRangeAt(feroz, 5).$2;
  final cap = ItemRules.forgeCapAt(Rarity.legendario, 5);

  int forgeRefund(int from, int to, WeaponDef base, Rarity r) {
    var t = 0;
    for (var l = to; l < from; l++) {
      t += CraftRules.forgeCost(base, r, l);
    }
    return t;
  }

  group('BalanceMigration', () {
    test('legendaria: mods fijos al nivel, forja al tope con devolución', () {
      final (acc, notice) =
          migrateAccountBalance(Account.fromJson(_v086Account()));
      final p = acc.byId('c1')!.profile;
      final leg = p.itemByUid('i1')!;
      expect(ferozMax, lessThan(28));
      expect(leg.affixes.first.value, ferozMax);
      expect(leg.forgeLevel, cap);
      // Se saca de la más alta (empate: la última), así que queda pow 2 /
      // crit 1.
      expect(cap, 3);
      expect(leg.forge.pow, 2);
      expect(leg.forge.crit, 1);
      final expected = forgeRefund(5, 2, w, Rarity.legendario) +
          forgeRefund(5, 1, w, Rarity.legendario);
      final epic = p.itemByUid('i2')!;
      expect(epic.extraSkills, ['chispa']);
      final skills = 2 * CraftRules.transferSkillCost(Rarity.epico);
      // Alijo: su forja +4 → 3 y el mod 30 → techo; créditos al elegido.
      final st = acc.stash.cells[0]!.item!;
      expect(st.affixes.single.value, ferozMax);
      expect(st.forgeLevel, cap);
      final stashForge = CraftRules.forgeCost(w, Rarity.legendario, 3);
      expect(p.credits, 1000 + expected + skills + stashForge);
      // Lo demás no cambia.
      expect(p.level, 8);
      expect(p.xp, 120);
      // Progresión v2 (bv 3): el árbol se devuelve entero.
      expect(p.tree, isEmpty);
      expect(p.material(CraftMaterial.esquirla), 4);
      expect(notice, contains('Rebalance v0.9'));
      expect(notice, contains('₵'));
    });

    test('idempotente: migrar dos veces no cambia nada', () {
      final (once, _) = migrateAccountBalance(Account.fromJson(_v086Account()));
      final (twice, notice) = migrateAccountBalance(once);
      expect(notice, isNull);
      expect(jsonEncode(twice.toJson()), jsonEncode(once.toJson()));
      final item = once.byId('c1')!.profile.itemByUid('i1')!;
      final (again, r) = const BalanceMigration().migrateItem(item);
      expect(r.isEmpty, isTrue);
      expect(identical(again, item), isTrue);
    });

    test('un arma dentro de las reglas no se toca', () {
      const ok = ItemInstance(
          uid: 'x',
          baseId: 'espada_templada',
          rarity: Rarity.legendario,
          itemLevel: 40,
          uniqueId: 'juramentoAlba',
          affixes: [AffixRoll('feroz', 0, 30)]);
      final (m, r) = craft.items.sanitize(ok) == null
          ? (ok, const BalanceRefund())
          : const BalanceMigration().migrateItem(ok);
      expect(r.isEmpty, isTrue);
      expect(m.affixes.single.value, 30);
    });
  });

  group('JsonFileAccountStore + migración', () {
    // Siempre en carpetas temporales: nunca la carpeta real del jugador.
    late Directory dir;
    setUp(() => dir = Directory.systemTemp.createTempSync('ecos_bv'));
    tearDown(() => dir.deleteSync(recursive: true));
    File at(String name) => File('${dir.path}${Platform.pathSeparator}$name');

    test('copia de seguridad, un aviso, guarda bv y corre una sola vez',
        () async {
      final original = jsonEncode(_v086Account());
      at('account.json').writeAsStringSync(original);
      final store =
          JsonFileAccountStore(dir, now: () => DateTime(2026, 11, 19, 10));
      final l = await store.load();
      expect(l.notice, contains('Rebalance v0.9'));
      final backup = at('account.pre-bv$kBalanceVersion-20261119-100000.json');
      expect(backup.readAsStringSync(), original);
      final saved =
          jsonDecode(at('account.json').readAsStringSync()) as Map;
      expect(saved['bv'], kBalanceVersion);
      expect(l.account.byId('c1')!.profile.itemByUid('i1')!.forgeLevel,
          ItemRules.forgeCapAt(Rarity.legendario, 5));

      final again = await JsonFileAccountStore(dir).load();
      expect(again.notice, isNull);
      expect(jsonEncode(again.account.toJson()),
          jsonEncode(l.account.toJson()));
      expect(
          dir.listSync().where((e) => e.path.contains('pre-bv')).length, 1);
    });
  });
}
