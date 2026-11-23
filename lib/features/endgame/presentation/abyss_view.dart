import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/feature_flags.dart';
import '../../../app/theme/panel_frame.dart';
import '../../../app/theme/panel_widgets.dart';
import '../../../app/theme/proto_colors.dart';
import '../../../app/theme/proto_markup.dart';
import '../../../app/theme/retro_theme.dart';
import '../../../app/widgets/action_card.dart';
import '../../../app/widgets/cost_chip.dart';
import '../../../app/widgets/menu_widgets.dart';
import '../../../app/widgets/pixel_icon.dart';
import '../../../game_engine/data/abyss_catalog.dart';
import '../../../game_engine/data/enemies_catalog.dart';
import '../../../game_engine/models/item.dart';
import '../../../game_engine/models/player_profile.dart';
import '../../../game_engine/models/session_action.dart';
import '../../../game_engine/rules/abyss_rules.dart';
import '../../combat/presentation/game_sprites.dart';
import '../../combat/presentation/pixel_sprite.dart';
import '../../world/presentation/session_controller.dart';
import '../../world/presentation/session_view.dart';
import '../domain/endgame_text.dart';
import '../../../core/i18n/i18n_providers.dart';

/// Pestaña ABISMO del Portal del Eco (docs/specs/abyss_bosses.md § 4):
/// tus Fragmentos, una tarjeta por Jefe del Abismo (silueta hasta
/// vencerlo; el secreto, oculto hasta vencer a los 4) y la ficha con
/// ABRIR → confirmar el costo.
class AbyssView extends ConsumerStatefulWidget {
  const AbyssView({
    super.key,
    required this.view,
    required this.controller,
    this.sprites,
  });

  final SessionView view;
  final SessionController controller;
  final GameSprites? sprites;

  @override
  ConsumerState<AbyssView> createState() => _AbyssViewState();
}

class _AbyssViewState extends ConsumerState<AbyssView> {
  int _sel = 1;
  bool _confirm = false;

  SessionController get c => widget.controller;

  @override
  Widget build(BuildContext context) {
    final p = widget.view.me!.profile;
    final rules = c.engine.abyssRules;
    final bosses = c.engine.catalog.abyssBosses.values.toList();
    final d = c.engine.catalog.abyssBosses[_sel] ?? bosses.first;
    final s = widget.view.session;
    final blocked = abyssOpenBlocked(s, p, d, rules);
    final dev = FeatureFlags.instance.devTools;
    final counter = kBossMechanics[kEnemies[d.enemyId]?.mechanicId]?.counter ?? '';
    return PanelSplit(
      listWidth: 560,
      list: [
        ProtoText(
            key: const ValueKey('abyss-fragments'),
            ref.t('ui.endgame.abyss.fragments',
                {'list': abyssFragmentsMarkup(p)})),
        const SizedBox(height: 8),
        CardGrid(
          minWidth: 250,
          children: [
            for (final b in bosses) _card(p, b, rules),
          ],
        ),
        if (dev) ...[
          const SizedBox(height: 8),
          Wrap(spacing: 6, runSpacing: 6, children: [
            PanelButton('DEV: +FRAGMENTOS',
                key: const ValueKey('abyss-dev-frag'),
                onPressed: () =>
                    setState(() => c.devAbyss(DevAbyssAction.fragments))),
            PanelButton('DEV: 4 VENCIDOS',
                key: const ValueKey('abyss-dev-kills'),
                onPressed: () =>
                    setState(() => c.devAbyss(DevAbyssAction.kills))),
          ]),
        ],
      ],
      detail: PanelDetail(
        footer: _confirm
            ? [
                ProtoText(
                    key: const ValueKey('abyss-confirm-text'),
                    protoColor(ProtoColors.orange,
                        ref.t('ui.endgame.abyss.confirm',
                            {'cost': protoEsc(rules.costText(d))}))),
                PanelButton(ref.t('ui.endgame.cancel'),
                    key: const ValueKey('abyss-cancel'),
                    onPressed: () => setState(() => _confirm = false)),
                PanelButton(ref.t('ui.endgame.confirm'),
                    key: const ValueKey('abyss-confirm'),
                    accent: ProtoColors.green,
                    reason: blocked, onPressed: () {
                  setState(() => _confirm = false);
                  if (c.proposeAbyss(d.number)) c.closePanel();
                }),
              ]
            : [
                KeyHints(
                    confirm: ref.t('ui.endgame.hint.choose'),
                    back: ref.t('ui.endgame.hint.close')),
                PanelButton(ref.t('ui.endgame.open'),
                    key: const ValueKey('abyss-open'),
                    accent: ProtoColors.green,
                    reason: blocked,
                    onPressed: () => setState(() => _confirm = true)),
              ],
        children: [
          ProtoText(
              key: const ValueKey('abyss-detail'),
              abyssDetailMarkup(p, d, rules,
                  d.secret && !AbyssRules.visible(p, d) ? '' : counter)),
        ],
      ),
    );
  }

  Widget _card(PlayerProfile p, AbyssBossDef b, AbyssRules rules) {
    final hidden = b.secret && !AbyssRules.visible(p, b);
    final reason = hidden ? ref.t('ui.endgame.abyss.beat_four') : null;
    final cost = rules.cost(b);
    return ActionCard(
      key: ValueKey('abyss-card-${b.number}'),
      title: protoEsc(abyssBossLabel(p, b)),
      icon: _sprite(p, b),
      selected: b.number == _sel,
      description: hidden
          ? ref.t('ui.endgame.abyss.requirement')
          : ref.t('ui.endgame.abyss.card', {
              'level': b.level,
              'phases': b.phases.length,
              'beaten': AbyssRules.known(p, b) ? 'yes' : 'no',
            }),
      reason: reason,
      footer: reason != null
          ? null
          : CostChip([
              for (final e in cost.entries)
                CostPart(PixelIconKind.shard,
                    '${p.material(e.key)}/${e.value} ${_short(e.key)}',
                    iconColor: ProtoColors.violet,
                    ok: p.material(e.key) >= e.value),
            ]),
      onTap: () => setState(() {
        _sel = b.number;
        _confirm = false;
      }),
    );
  }

  static String _short(CraftMaterial m) =>
      m.label.replaceFirst('Fragmento ', '').replaceFirst('del ', '').replaceFirst('de la ', '').replaceFirst('de las ', '');

  /// Sprite del jefe: silueta hasta vencerlo (y candado si es el secreto
  /// oculto).
  Widget _sprite(PlayerProfile p, AbyssBossDef b) {
    final box = RetroType.width(context, 30);
    final img = widget.sprites?.enemy(b.enemyId);
    if (img == null || (b.secret && !AbyssRules.visible(p, b))) {
      return PixelIcon(b.secret ? PixelIconKind.lock : PixelIconKind.shard,
          size: box * 0.6, color: ProtoColors.violet);
    }
    final scale = (box / (img.height > img.width ? img.height : img.width))
        .floorToDouble()
        .clamp(1.0, 4.0);
    final s = PixelSprite(img, scale: scale);
    return AbyssRules.known(p, b)
        ? s
        : ColorFiltered(
            colorFilter:
                const ColorFilter.mode(ProtoColors.barBg, BlendMode.srcIn),
            child: s);
  }
}
