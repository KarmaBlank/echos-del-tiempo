import 'data/ascension_catalog.dart';
import 'data/ascension_mechanics.dart';
import 'data/classes_catalog.dart';
import 'data/enemies_catalog.dart';
import 'data/passive_mechanics.dart';
import 'data/passive_tree_catalog.dart';
import 'data/passive_tree_v6.dart';
import 'data/skills_catalog.dart';
import 'data/summoner_catalog.dart';
import 'data/branch_ults_catalog.dart';
import 'data/ults_v2_catalog.dart';
import 'data/weapon_duals_catalog.dart';
import 'data/enemy_families.dart';
import 'models/elements.dart';
import 'models/status.dart';

/// String keys of the combat catalogs (docs/specs/i18n.md § 3.4). The
/// engine keeps ids and its es-AR literals (source of the extractor);
/// presentation resolves the text with these keys.
class CatalogKeys {
  const CatalogKeys._();

  /// An id as a key segment: only `[A-Za-z0-9_]` (accents dropped, the
  /// rest becomes `_`).
  static String seg(String id) {
    const from = 'áéíóúñÁÉÍÓÚÑü';
    const to = 'aeiounAEIOUNu';
    final b = StringBuffer();
    for (final r in id.runes) {
      final c = String.fromCharCode(r);
      final i = from.indexOf(c);
      if (i >= 0) {
        b.write(to[i]);
      } else if (RegExp(r'[A-Za-z0-9_]').hasMatch(c)) {
        b.write(c);
      } else {
        b.write('_');
      }
    }
    return b.toString();
  }

  static String className(String id) => 'data.classes.${seg(id)}.name';
  static String classDesc(String id) => 'data.classes.${seg(id)}.desc';
  static String skillName(String id) => 'data.skills.${seg(id)}.name';
  static String ultName(String id) => 'data.ults.${seg(id)}.name';
  static String ultHow(String id) => 'data.ults.${seg(id)}.how';
  static String dualName(String key) => 'data.ults.dual.${seg(key)}.name';
  static String enemyUltName(String id) => 'data.ults.enemy.${seg(id)}.name';
  static String nodeName(String id) => 'data.passives.node.${seg(id)}.name';
  static String pathName(String id) => 'data.passives.path.${seg(id)}.name';
  static String pathTheme(String id) => 'data.passives.path.${seg(id)}.theme';
  static String mechName(String id) => 'data.passives.mech.${seg(id)}.name';
  static String mechDesc(String id) => 'data.passives.mech.${seg(id)}.desc';
  static String ascName(String id) => 'data.passives.asc.${seg(id)}.name';
  static String ascTheme(String id) => 'data.passives.asc.${seg(id)}.theme';
  static String ascMotto(String id) => 'data.passives.asc.${seg(id)}.motto';
  static String ascNodeName(String id) =>
      'data.passives.ascnode.${seg(id)}.name';
  /// Name of branch [i] (0–4) of ascension [asc] (ascension.md § 3.2).
  static String ascBranch(String asc, int i) =>
      'data.passives.ascbranch.${asc}_$i';
  static String ascNodeText(String id) =>
      'data.passives.ascnode.${seg(id)}.text';
  static String element(GameElement e) => 'data.elements.element.${e.name}';
  static String status(StatusKind k) => 'data.elements.status.${k.name}';
  static String reaction(ReactionKind k) => 'data.elements.reaction.${k.name}';
  static String summon(SummonKind k) => 'data.elements.summon.${k.name}';
  static String damageTag(DamageTag t) => 'data.elements.tag.${t.name}';
}

/// Every es-AR source text of the combat catalogs by key (the extractor
/// `tool/i18n/extract_combat_catalogs.dart` writes it to es-AR and a test
/// keeps both in sync).
Map<String, String> sourceCatalogTexts() {
  final m = <String, String>{};
  void put(String k, String v) {
    if (v.trim().isEmpty) return;
    m.putIfAbsent(k, () => v);
  }

  for (final c in kClasses.values) {
    put(CatalogKeys.className(c.id), c.name);
    put(CatalogKeys.classDesc(c.id), c.description);
  }
  for (final s in kSkills.values) {
    put(CatalogKeys.skillName(s.id), s.name);
  }
  for (final s in [
    ...kAllUltimates.values,
    ...kWeaponUltSkills.values,
    ...kAscensionUltimates.values,
  ]) {
    put(CatalogKeys.ultName(s.id), s.name);
  }
  for (final u in kUltV2List) {
    put(CatalogKeys.ultHow(u.id), u.how);
  }
  kAllDuals.forEach((k, d) => put(CatalogKeys.dualName(k), d.name));
  for (final u in [...kEnemyUlts.values, ...kEliteUlts.values]) {
    put(CatalogKeys.enemyUltName(u.id), u.name);
  }
  for (final n in kPassiveTree.nodes.values) {
    put(CatalogKeys.nodeName(n.id), n.name);
  }
  for (final p in kPassiveTree.paths.values) {
    put(CatalogKeys.pathName(p.id), p.name);
    put(CatalogKeys.pathTheme(p.id), p.theme);
  }
  for (final mech in [
    ...kMechanics.values,
    ...kAscensionMechanics.values,
    ...kTreeV6Mechanics,
    ...kTreeV6SmallMechanics,
    ...kSummonerTreeMechanics,
  ]) {
    put(CatalogKeys.mechName(mech.id), mech.name);
    put(CatalogKeys.mechDesc(mech.id), mech.description);
  }
  for (final a in kAscensions.values) {
    put(CatalogKeys.ascName(a.id), a.name);
    put(CatalogKeys.ascTheme(a.id), a.theme);
    put(CatalogKeys.ascMotto(a.id), a.motto);
    for (final (i, b) in branchesOf(a.id).indexed) {
      put(CatalogKeys.ascBranch(a.id, i), b.name);
    }
    for (final n in a.nodes) {
      put(CatalogKeys.ascNodeName(n.id), n.name);
      put(CatalogKeys.ascNodeText(n.id), n.text);
    }
  }
  for (final e in GameElement.values) {
    put(CatalogKeys.element(e), e.label);
  }
  for (final k in StatusKind.values) {
    put(CatalogKeys.status(k), k.label);
  }
  for (final k in ReactionKind.values) {
    put(CatalogKeys.reaction(k), k.label);
  }
  for (final s in kSummons.values) {
    put(CatalogKeys.summon(s.kind), s.name);
  }
  for (final t in DamageTag.values) {
    put(CatalogKeys.damageTag(t), t.label);
  }
  return m;
}
