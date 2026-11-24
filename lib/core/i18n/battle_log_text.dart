import '../../game_engine/data/ascension_catalog.dart';
import '../../game_engine/data/branch_ults_catalog.dart';
import '../../game_engine/data/game_catalog.dart';
import '../../game_engine/data/skills_catalog.dart';
import '../../game_engine/data/summoner_catalog.dart';
import '../../game_engine/models/battle_log.dart';
import '../../game_engine/models/elements.dart';
import '../../game_engine/models/skill.dart';
import '../../game_engine/models/status.dart';
import 'catalog_names.dart';
import 'game_text.dart';
import 'strings.dart';

/// A battle log line ([LogLine]) as text in the active language
/// (docs/specs/i18n.md § 3.4). [strings] defaults to [GameText.strings].
String battleLogText(LogLine line, {Strings? strings}) {
  final s = strings ?? GameText.strings;
  String fmt(LogLine l) {
    if (l.isEmpty) return '';
    final raw = l.rawText;
    if (raw != null) return raw;
    final id = '${l.args['id'] ?? ''}';
    final n = '${l.args['n'] ?? id}';
    if (l.key.startsWith('@') && s.isSource) return n;
    switch (l.key) {
      case LogLine.joinKey:
        return [
          for (final p in (l.args['p'] as List? ?? const []))
            if (p is LogLine) fmt(p),
        ].where((t) => t.isNotEmpty).join('${l.args['s'] ?? ' · '}');
      case LogLine.upperKey:
        final x = l.args['x'];
        return x is LogLine ? fmt(x).toUpperCase() : '';
      case LogLine.namedRef:
        return GameText.name('${l.args['k']}', n);
      case LogLine.skillRef:
        return _skillsById[id]?.tr ?? n;
      case LogLine.dualRef:
        final d = GameCatalog.standard.duals[id];
        return d == null ? n : dualNameTr(id, d);
      case LogLine.enemyUltRef:
        return GameCatalog.standard.enemyUlts[id]?.tr ?? n;
      case LogLine.statusRef:
        return StatusKind.values.where((k) => k.name == id).firstOrNull?.tr ??
            id;
      case LogLine.reactionRef:
        return ReactionKind.values.where((k) => k.name == id).firstOrNull?.tr ??
            id;
      case LogLine.summonRef:
        final k = SummonKind.values.where((k) => k.name == id).firstOrNull;
        return k == null ? n : (kSummons[k]?.tr ?? n);
    }
    final args = <String, Object?>{
      for (final e in l.args.entries)
        e.key: switch (e.value) {
          final LogLine v => fmt(v),
          final List v => [
              for (final x in v)
                if (x is LogLine) fmt(x),
            ].where((t) => t.isNotEmpty).join(' · '),
          final v => v,
        },
    };
    return s.t(l.key, args);
  }

  // Catalog names ([GameText.name]) read the same tables.
  final prev = GameText.current;
  if (strings != null) GameText.current = strings;
  try {
    return fmt(line);
  } finally {
    GameText.current = prev;
  }
}

/// Every skill and ULT by id (the ULTs by weapon type are keyed by type).
final Map<String, SkillDef> _skillsById = {
  ...kSkills,
  for (final u in kAllUltimates.values) u.id: u,
  ...kWeaponUltSkills,
  for (final u in kAscensionUltimates.values) u.id: u,
};
