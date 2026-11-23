import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/design/design.dart';
import '../../../game_engine/data/tuning_catalog.dart';
import '../../../game_engine/models/travesia_meta.dart';
import '../../../game_engine/rules/meta_progress_rules.dart';
import '../../world/presentation/session_controller.dart';
import '../../../core/i18n/i18n_providers.dart';

/// Preparación de la Travesía (organismo; docs/specs/roguelike.md § 8):
/// moneda, dificultad, loadout (2 habilidades de arranque) y árbol de
/// afuera del personaje. Solo arma la vista; guarda el controlador.
class RunPrepView extends ConsumerWidget {
  const RunPrepView({super.key, required this.controller});

  final SessionController controller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = controller;
    final m = c.meta;
    final key = c.metaKey;
    if (key == null) return const SizedBox.shrink();
    final ch = m.charOf(key);
    final pool = c.loadoutPool;
    final open = MetaProgressRules.openCount(ch.nodes);
    final skills = c.engine.catalog.skills;
    final zonesStart = tuning(TuningId.travesia).i('zonesStart');

    Widget section(String title, List<Widget> rows) => Padding(
          padding: EdgeInsets.only(bottom: DsSpace.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DsSectionHeader(title),
              SizedBox(height: DsSpace.xs),
              ...rows,
            ],
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
            ref.t('ui.run.prep.meta', {
              'coins': m.coins,
              'runs': m.runs,
              'wins': m.wins,
              'zones': zonesStart + m.zones,
            }),
            key: const ValueKey('run-meta-coins'),
            style: DsText.subtitle()),
        SizedBox(height: DsSpace.sm),
        if (!c.isClient)
          section(ref.t('ui.run.prep.difficulty'), [
            Wrap(
              spacing: DsSpace.sm,
              runSpacing: DsSpace.xs,
              children: [
                for (var d = 0; d <= m.difficultyUnlocked; d++)
                  DsButton(
                      d == 0
                          ? ref.t('ui.run.prep.normal')
                          : ref.t('ui.run.prep.level', {'level': d}),
                      key: ValueKey('run-diff-$d'),
                      size: DsButtonSize.compact,
                      selected: m.difficulty == d,
                      onPressed: () => c.setDifficulty(d)),
              ],
            ),
            Text(
                ref.t('ui.run.prep.difficulty_hint'),
                style: DsText.detail()),
          ]),
        section(
            ref.t('ui.run.prep.loadout', {
              'n': ch.loadout.length,
              'max': MetaProgressRules.loadoutSlots,
            }),
            [
              Wrap(
                spacing: DsSpace.sm,
                runSpacing: DsSpace.sm,
                children: [
                  for (var i = 0; i < pool.length; i++)
                    SizedBox(
                      width: 220,
                      child: DsCard(
                        key: ValueKey('run-loadout-${pool[i]}'),
                        selected: ch.loadout.contains(pool[i]),
                        onTap: i >= open
                            ? null
                            : () => _toggle(c, ch, pool[i]),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(skills[pool[i]]?.name ?? pool[i],
                                style: DsText.subtitle(i >= open
                                    ? DsColors.textDisabled
                                    : null)),
                            Text(
                                i >= open
                                    ? ref.t('ui.run.prep.opens_with_repertoire')
                                    : '${skills[pool[i]]?.mp ?? 0} MP',
                                style: DsText.detail()),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              Text(ref.t('ui.run.prep.loadout_hint'),
                  style: DsText.detail()),
            ]),
        section(ref.t('ui.run.prep.legacy'), [
          for (final n in kMetaNodes)
            Padding(
              padding: EdgeInsets.only(bottom: DsSpace.xs),
              child: Row(
                children: [
                  Expanded(
                    child: Text('${n.name}: ${n.text}',
                        style: DsText.body(ch.nodes.contains(n.id)
                            ? DsColors.selected
                            : DsColors.text)),
                  ),
                  if (ch.nodes.contains(n.id))
                    Text(ref.t('ui.run.prep.taken'), style: DsText.detail())
                  else
                    DsButton(ref.t('ui.run.prep.cost', {'n': n.cost}),
                        key: ValueKey('run-meta-${n.id}'),
                        size: DsButtonSize.compact,
                        tooltip: MetaProgressRules.cantBuy(n, ch, m.coins),
                        onPressed:
                            MetaProgressRules.cantBuy(n, ch, m.coins) != null
                                ? null
                                : () => c.buyMetaNode(n.id)),
                ],
              ),
            ),
        ]),
      ],
    );
  }

  static void _toggle(SessionController c, TravesiaCharMeta ch, String id) {
    final now = [...ch.loadout];
    if (now.contains(id)) {
      now.remove(id);
    } else {
      if (now.length >= MetaProgressRules.loadoutSlots) now.removeAt(0);
      now.add(id);
    }
    c.setLoadout(now);
  }
}
