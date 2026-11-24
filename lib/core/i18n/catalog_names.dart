import '../../game_engine/catalog_text_keys.dart';
import '../../game_engine/data/summoner_catalog.dart';
import '../../game_engine/models/ascension.dart';
import '../../game_engine/models/class_def.dart';
import '../../game_engine/models/elements.dart';
import '../../game_engine/models/enemy_def.dart';
import '../../game_engine/models/passive_mechanic.dart';
import '../../game_engine/models/passive_tree.dart';
import '../../game_engine/models/skill.dart';
import '../../game_engine/models/status.dart';
import 'game_text.dart';

// Catalog text in the active language (docs/specs/i18n.md § 3.4): the
// engine keeps ids and es-AR literals; the UI shows `x.tr`.

/// Whether [key] has text in some table (active language or es-AR).
bool _has(String key) => GameText.strings.t(key) != key;

extension SkillDefTr on SkillDef {
  /// Name of a skill or ULT.
  String get tr {
    final k = CatalogKeys.skillName(id);
    return GameText.name(_has(k) ? k : CatalogKeys.ultName(id), name);
  }
}

/// Name of the dual attack [key] (`GameCatalog.duals`).
String dualNameTr(String key, DualDef d) =>
    GameText.name(CatalogKeys.dualName(key), d.name);

extension ClassDefTr on ClassDef {
  String get tr => GameText.name(CatalogKeys.className(id), name);
  String get descTr => GameText.name(CatalogKeys.classDesc(id), description);
}

/// Name of the class [id] (or [fallback] / the id if unknown).
String classNameTr(String id, [String? fallback]) =>
    GameText.name(CatalogKeys.className(id), fallback ?? id);

extension EnemyUltDefTr on EnemyUltDef {
  String get tr => GameText.name(CatalogKeys.enemyUltName(id), name);
}

extension PassiveNodeTr on PassiveNode {
  String get tr => GameText.name(CatalogKeys.nodeName(id), name);
}

extension PassivePathTr on PassivePath {
  String get tr => GameText.name(CatalogKeys.pathName(id), name);
  String get themeTr => GameText.name(CatalogKeys.pathTheme(id), theme);
}

extension PassiveMechanicTr on PassiveMechanic {
  String get tr => GameText.name(CatalogKeys.mechName(id), name);
  String get descTr => GameText.name(CatalogKeys.mechDesc(id), description);
}

extension AscensionDefTr on AscensionDef {
  String get tr => GameText.name(CatalogKeys.ascName(id), name);
  String get themeTr => GameText.name(CatalogKeys.ascTheme(id), theme);
  String get mottoTr => GameText.name(CatalogKeys.ascMotto(id), motto);
}

extension AscensionNodeTr on AscensionNode {
  String get tr => GameText.name(CatalogKeys.ascNodeName(id), name);
  String get textTr => GameText.name(CatalogKeys.ascNodeText(id), text);
}

extension GameElementTr on GameElement {
  String get tr => GameText.name(CatalogKeys.element(this), label);
}

extension StatusKindTr on StatusKind {
  String get tr => GameText.name(CatalogKeys.status(this), label);
}

extension ReactionKindTr on ReactionKind {
  String get tr => GameText.name(CatalogKeys.reaction(this), label);
}

extension SummonDefTr on SummonDef {
  String get tr => GameText.name(CatalogKeys.summon(kind), name);
}
