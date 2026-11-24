import '../../../core/i18n/data_text.dart';
import '../../../core/i18n/game_text.dart';
import '../../../game_engine/data/trials_catalog.dart';
import '../../../game_engine/models/abyss.dart';
import '../../../game_engine/models/atlas.dart';
import '../../../game_engine/models/item.dart';
import '../../../game_engine/models/zone_def.dart';

// Endgame catalog text in the active language (docs/specs/i18n.md § 3.6):
// the engine keeps ids and es-AR literals; the UI shows `x.tr`. In es-AR
// these return the literal as is.

String _data(String key, String source) =>
    GameText.strings.data(key, source);

extension AtlasNodeDefTr on AtlasNodeDef {
  String get tr =>
      _data('ui.endgame.atlas.node.${DataKeys.slug(id)}.name', name);
  String get textTr =>
      _data('ui.endgame.atlas.node.${DataKeys.slug(id)}.text', text);
}

extension AtlasBranchTr on AtlasBranch {
  String get tr => _data('ui.endgame.atlas.branch.$name', label);
}

extension AbyssPhaseTr on AbyssBossDef {
  /// Name of the phase [i] of this boss.
  String phaseTr(int i) =>
      _data('ui.endgame.abyss.phase.$number.$i', phases[i].name);

  /// Boss name (the enemy catalog's text for its enemy id).
  String get tr => _data(DataKeys.enemyName(enemyId), name);
}

extension EndgameMaterialTr on CraftMaterial {
  /// Name of an endgame material (Fragments, Essence, Eco crafting).
  String get endgameTr =>
      _data('ui.endgame.material.${DataKeys.slug(name)}', label);
}

extension TrialDefTr on TrialDef {
  String get tr => _data('ui.ascension.trial.name.$number', name);

  /// `Prueba del Tiempo II · La Encrucijada`.
  String get fullNameTr =>
      GameText.t('ui.ascension.trial.full_name', {'roman': roman, 'name': tr});
}

extension ZoneDefTr on ZoneDef {
  String get tr => _data(DataKeys.zoneName(id), name);
  String get bossTr => _data(DataKeys.enemyName(bossId), bossName);
}
