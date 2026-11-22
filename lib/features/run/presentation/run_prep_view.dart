import 'package:material_ui/material_ui.dart';

import '../../../app/design/design.dart';
import '../../../game_engine/data/tuning_catalog.dart';
import '../../../game_engine/models/travesia_meta.dart';
import '../../../game_engine/rules/meta_progress_rules.dart';
import '../../world/presentation/session_controller.dart';

/// Preparación de la Travesía (organismo; docs/specs/roguelike.md § 8):
/// moneda, dificultad, loadout (2 habilidades de arranque) y árbol de
/// afuera del personaje. Solo arma la vista; guarda el controlador.
class RunPrepView extends StatelessWidget {
  const RunPrepView({super.key, required this.controller});

  final SessionController controller;

  @override
  Widget build(BuildContext context) {
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
            'Ecos: ${m.coins} · Travesías: ${m.runs} (ganadas ${m.wins}) · '
            'Zonas en el sorteo: ${zonesStart + m.zones}',
            key: const ValueKey('run-meta-coins'),
            style: DsText.subtitle()),
        SizedBox(height: DsSpace.sm),
        if (!c.isClient)
          section('DIFICULTAD', [
            Wrap(
              spacing: DsSpace.sm,
              runSpacing: DsSpace.xs,
              children: [
                for (var d = 0; d <= m.difficultyUnlocked; d++)
                  DsButton(d == 0 ? 'NORMAL' : 'NIVEL $d',
                      key: ValueKey('run-diff-$d'),
                      size: DsButtonSize.compact,
                      selected: m.difficulty == d,
                      onPressed: () => c.setDifficulty(d)),
              ],
            ),
            Text(
                'Cada nivel suma vida y ataque a los enemigos. Ganá en la '
                'más alta para abrir la siguiente.',
                style: DsText.detail()),
          ]),
        section(
            'HABILIDADES DE ARRANQUE (${ch.loadout.length}/'
            '${MetaProgressRules.loadoutSlots})',
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
                                    ? 'Se abre con Repertorio'
                                    : '${skills[pool[i]]?.mp ?? 0} MP',
                                style: DsText.detail()),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
              Text('Se suman a las de tu arma durante toda la Travesía.',
                  style: DsText.detail()),
            ]),
        section('LEGADO DEL VIAJERO', [
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
                    Text('TOMADO', style: DsText.detail())
                  else
                    DsButton('${n.cost} ECOS',
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
