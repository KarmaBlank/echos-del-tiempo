import 'package:material_ui/material_ui.dart';

import '../../../app/design/design.dart';
import '../../../core/i18n/strings.dart';
import '../../../game_engine/data/zone_bosses_catalog.dart';
import '../../../game_engine/models/battle_state.dart';
import '../../../game_engine/rules/abyss_rules.dart';

/// Text key of each phase / move label of the zone bosses.
const _labelKeys = {
  'Corte de Gel': 'corte_gel',
  'División': 'division',
  'Marea Real': 'marea_real',
  'Ola Ácida': 'ola_acida',
};

String _label(Strings s, String label) {
  final k = _labelKeys[label];
  return k == null ? label : s.t('ui.combat.boss_bar.label.$k');
}

/// The boss bar of [b] (bosses.md § v0.50 § 3): only with a living phased
/// zone boss; `null` otherwise.
Widget? zoneBossBar(Strings s, BattleState b, {bool eco = false}) {
  for (final e in b.enemies) {
    final d = zonePhasesOf(e);
    if (d == null || !e.alive) continue;
    final i = AbyssRules.phaseIndex(d, e);
    final ph = AbyssRules.phaseOf(d, e);
    final next = AbyssRules.nextMove(d, e);
    return DsBossHealthBar(
      key: const ValueKey('zone-boss-bar'),
      name: e.name,
      hp: e.hp,
      maxHp: e.maxHp,
      gates: [for (final p in d.phases.skip(1)) p.gate],
      phaseText: s.t('ui.combat.boss_bar.phase', {
        'n': i + 1,
        'of': d.phases.length,
        'name': _label(s, ph.name),
      }),
      nextText: next.kind.telegraphed
          ? s.t('ui.combat.boss_bar.next', {'move': _label(s, next.label)})
          : null,
      tag: eco ? s.t('ui.combat.boss_bar.eco') : null,
      danger: i == d.phases.length - 1,
    );
  }
  return null;
}
