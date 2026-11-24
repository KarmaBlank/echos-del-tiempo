import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/design/design.dart';
import '../../../app/theme/retro_text.dart';
import '../../../app/theme/retro_theme.dart';
import '../../../app/widgets/pixel_icon.dart';
import '../../../core/i18n/data_text.dart';
import '../../../core/i18n/i18n_providers.dart';
import '../../../game_engine/data/achievements_catalog.dart';
import '../../../game_engine/models/achievement.dart';
import 'achievement_feed.dart' show achievementNameText, achievementRewardText;

/// Filtro de la pestaña.
enum AchievementFilter {
  all,
  pending,
  done;

  /// Key of the tab label (`ui.achievements.filter.<name>`).
  String get labelKey => 'ui.achievements.filter.$name';
}

/// La pestaña HAZAÑAS (docs/specs/achievements.md § 7): `logradas/33`,
/// filtro, secciones por categoría (pendientes primero) y una fila de una
/// línea por hazaña; el cómo se consigue va en el tooltip. Solo lectura.
class AchievementsView extends ConsumerStatefulWidget {
  const AchievementsView({super.key, required this.progress});

  final AchievementProgress progress;

  static const help = '<b>Hazañas</b><br>'
      'Una vez por cuenta: cada una paga créditos, materiales o pociones '
      'al personaje con el que la lográs. Funcionan como guía: pasá el '
      'mouse por una fila (o mantenela apretada) para ver cómo se '
      'consigue.<br>'
      'Las de contador (II, III) cuentan desde que existen las hazañas.';

  @override
  ConsumerState<AchievementsView> createState() => _AchievementsViewState();
}

class _AchievementsViewState extends ConsumerState<AchievementsView> {
  var _filter = AchievementFilter.all;

  AchievementProgress get _p => widget.progress;

  bool _show(AchievementDef d) => switch (_filter) {
        AchievementFilter.all => true,
        AchievementFilter.pending => !_p.isDone(d.id),
        AchievementFilter.done => _p.isDone(d.id),
      };

  @override
  Widget build(BuildContext context) {
    final done = kAchievements.where((d) => _p.isDone(d.id)).length;
    final rows = <Widget>[];
    for (final cat in AchievementCategory.values) {
      final list = [
        for (final d in kAchievements)
          if (d.category == cat && _show(d)) d
      ];
      if (list.isEmpty) continue;
      // Pendientes primero dentro de cada sección (§ 7).
      list.sort((a, b) {
        final x = _p.isDone(a.id) ? 1 : 0, y = _p.isDone(b.id) ? 1 : 0;
        if (x != y) return x - y;
        return kAchievements.indexOf(a) - kAchievements.indexOf(b);
      });
      final got = list.where((d) => _p.isDone(d.id)).length;
      rows.add(DsSectionHeader(
          ref.strings.data(DataKeys.achievementCategory(cat.name), cat.label),
          key: ValueKey('ach-section-${cat.name}'),
          trailing: Text('$got/${list.length}', style: DsText.detail())));
      for (final d in list) {
        rows.add(AchievementRow(def: d, progress: _p));
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: DsSpace.md,
          runSpacing: DsSpace.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text.rich(
              key: const ValueKey('ach-count'),
              TextSpan(children: [
                TextSpan(text: ref.t('ui.achievements.done_count'), style: DsText.detail()),
                TextSpan(text: '$done', style: DsText.body(DsColors.reward)),
                TextSpan(
                    text: '/${kAchievements.length}',
                    style: DsText.body(DsColors.textPrimary)),
              ]),
            ),
            DsTabBar(
              key: const ValueKey('ach-filter'),
              tabs: [
                for (final f in AchievementFilter.values)
                  DsTab(ref.t(f.labelKey), key: ValueKey('ach-filter-${f.name}')),
              ],
              index: _filter.index,
              onChanged: (i) =>
                  setState(() => _filter = AchievementFilter.values[i]),
            ),
          ],
        ),
        SizedBox(height: DsSpace.xs),
        Expanded(
          child: rows.isEmpty
              ? Padding(
                  padding: EdgeInsets.all(DsSpace.md),
                  child: Text(ref.t('ui.achievements.empty'),
                      key: const ValueKey('ach-empty'),
                      style: DsText.detail()),
                )
              : ListView(
                  key: const ValueKey('ach-list'),
                  children: rows,
                ),
        ),
      ],
    );
  }
}

/// Fila de una línea (§ 7): marca, nombre, progreso de las de contador y
/// recompensa a la derecha. El detalle va en el tooltip.
class AchievementRow extends ConsumerWidget {
  const AchievementRow({super.key, required this.def, required this.progress});

  final AchievementDef def;
  final AchievementProgress progress;

  static const minHeight = 32.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = achievementNameText(ref.strings, def);
    final done = progress.isDone(def.id);
    final c = def.counter;
    final count = c == null ? null : progress.count(c);
    final progressText = c == null || done
        ? null
        : '${count! > def.goal ? def.goal : count}/${def.goal}';
    final when = progress.done[def.id];
    final mark = done
        ? PixelIcon(PixelIconKind.check,
            size: RetroType.width(context, 12), color: DsColors.reward)
        : Container(
            width: RetroType.width(context, 12),
            height: RetroType.width(context, 12),
            decoration: BoxDecoration(
                border: Border.all(color: DsColors.textDisabled, width: 2)),
          );
    return Semantics(
      label: '$name, ${ref.t(done ? 'ui.achievements.state.done' : 'ui.achievements.state.pending')}',
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: minHeight),
        child: DsListRow(
          key: ValueKey('ach-row-${def.id}'),
          title: retroText(name),
          titleColor: done ? DsColors.reward : DsColors.textPrimary,
          detail: progressText,
          leading: SizedBox(
              width: RetroType.width(context, 14),
              child: Center(child: mark)),
          trailing: ConstrainedBox(
            constraints: BoxConstraints(
                maxWidth: RetroType.width(context, 240)),
            child: Text(retroText(def.reward.short),
                key: ValueKey('ach-reward-${def.id}'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: DsText.detail(
                    done ? DsColors.textSecondary : DsColors.reward)),
          ),
          tooltip: DsTooltipCard(
            title: retroText(name),
            titleColor: done ? DsColors.reward : DsColors.textPrimary,
            children: [
              Text(retroText(ref.strings.data(DataKeys.achievementHow(def.id), def.how)), style: DsText.detail(DsColors.text)),
              SizedBox(height: DsSpace.xs),
              Text(
                  retroText(ref.t('ui.achievements.reward',
                      {'reward': achievementRewardText(ref.strings, def.reward)})),
                  style: DsText.detail(DsColors.reward)),
              if (progressText != null)
                Text(
                    ref.t('ui.achievements.progress',
                        {'progress': progressText}),
                    style: DsText.detail()),
              Text(
                  done
                      ? (when != null && when > 0
                          ? ref.t('ui.achievements.done_on',
                              {'date': _date(when)})
                          : ref.t('ui.achievements.state.done'))
                      : ref.t('ui.achievements.state.pending'),
                  style: DsText.detail()),
            ],
          ),
        ),
      ),
    );
  }

  static String _date(int s) {
    final d = DateTime.fromMillisecondsSinceEpoch(s * 1000);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)}/${d.year}';
  }
}
