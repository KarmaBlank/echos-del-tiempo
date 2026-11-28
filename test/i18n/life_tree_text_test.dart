import 'package:echos_del_tiempo/core/i18n/string_tables.dart';
import 'package:echos_del_tiempo/game_engine/data/life_tree_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every node of every profession tree resolves to real text (name,
/// branch and each effect line) in every language, so the OFICIOS tab
/// never shows a raw key (life_trees_v2.md § 3).
void main() {
  final tables = StringTables.loadDirectorySync(StringTables.assetRoot)!;

  void expectText(String key) {
    for (final l in tables.registry.status.keys) {
      final e = tables.tables[l]?[key];
      expect(e, isNotNull, reason: '${l.tag} sin $key');
      expect(e!.text.trim(), isNotEmpty, reason: '${l.tag} vacío $key');
      expect(e.text, isNot(key), reason: '${l.tag} $key');
    }
  }

  test('cada nodo de oficio tiene nombre y efectos traducidos', () {
    for (final entry in kLifeTrees.entries) {
      final k = entry.key;
      for (final b in lifeBranchesOf(k)) {
        expectText('data.life_trees.branch.${k.name}.$b');
      }
      expect(entry.value, isNotEmpty, reason: k.name);
      for (final n in entry.value) {
        expectText('data.life_trees.node.${n.id}.name');
        for (final fx in n.effects.keys) {
          expectText('ui.town.trades.fx.$fx');
        }
      }
    }
  });
}
