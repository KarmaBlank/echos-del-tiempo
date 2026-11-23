import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/panel_frame.dart';
import '../../../app/theme/panel_widgets.dart';
import '../../../app/design/design.dart';
import '../../../app/theme/proto_colors.dart';

import '../../../app/theme/proto_markup.dart';
import '../../../app/theme/retro_theme.dart';
import '../../../game_engine/models/mission_def.dart';
import '../../../game_engine/models/turn_timer.dart';
import '../../../game_engine/models/combat_mode.dart';
import '../../../app/widgets/menu_focus.dart';
import '../../../app/widgets/menu_widgets.dart';
import '../../../app/widgets/pixel_icon.dart';
import '../../../app/widgets/section_panel.dart';
import 'mission_card.dart';
import '../../../core/i18n/i18n_providers.dart';

/// Un jugador en la lista de preparación.
class PrepEntry {
  const PrepEntry(this.name, this.className, this.level,
      {required this.ready, this.isLocal = false});
  final String name;
  final String className;
  final int level;
  final bool ready;
  final bool isLocal;
}

/// Fase de preparación (`prep` del prototipo, líneas 1341-1349) en
/// pestañas: MISIÓN (tarjeta, quién está listo, tu equipo) y las de la
/// tienda ([shopTabs]). `¡LISTO!` es el primario, abajo a la derecha en
/// todas las pestañas. Ver docs/specs/panels.md § "Preparación".
class PrepPanel extends ConsumerStatefulWidget {
  const PrepPanel({
    super.key,
    required this.mission,
    required this.players,
    required this.ready,
    required this.credits,
    required this.weaponName,
    required this.onReady,
    required this.onCancel,
    required this.onCharacter,
    this.tier = 1,
    this.bossName,
    this.potions = 0,
    this.ethers = 0,
    this.shopTabs = const [],
    this.turnTimer = TurnTimer.normal,
    this.combatMode = CombatMode.timeline,
    this.onCombatMode,
    this.members,
  });

  /// Modo de combate de la sala (turn_modes.md § 1): lo elige el
  /// anfitrión ([onCombatMode] no nulo); el resto lo ve.
  final CombatMode combatMode;
  final ValueChanged<CombatMode>? onCombatMode;

  /// Selector de miembro de la party jugando solo, arriba de las pestañas
  /// (solo_party.md § 6.2); `null` = sin selector.
  final Widget? members;

  /// Tiempo de turno de la sala (lo elige el anfitrión).
  final TurnTimer turnTimer;

  final MissionDef mission;
  final List<PrepEntry> players;

  /// El jugador local ya marcó ¡Listo!.
  final bool ready;
  final int credits;
  final String weaponName;
  final ValueChanged<bool> onReady;
  final VoidCallback onCancel;
  final VoidCallback onCharacter;

  /// Nº de misión (tier de las armas que suelta).
  final int tier;
  final String? bossName;
  final int potions;
  final int ethers;

  /// Pestañas de tienda (COMPRAR, FORJA, FUSIÓN, CONSUMIBLES).
  final List<PanelTabSpec> shopTabs;

  @override
  ConsumerState<PrepPanel> createState() => _PrepPanelState();
}

class _PrepPanelState extends ConsumerState<PrepPanel> {
  /// Modo de combate: selector para el anfitrión, texto para el resto;
  /// el tooltip explica el modo en una línea.
  Widget _combatModeLine() {
    final w = widget;
    final on = w.onCombatMode;
    final child = on == null
        ? InfoLine(ref.t('ui.missions.prep.combat'),
            ref.t('ui.missions.prep.host_picks', {'value': w.combatMode.label}),
            labelEms: 13)
        : Padding(
            padding: EdgeInsets.symmetric(
                horizontal: DsSpace.md, vertical: DsSpace.xs),
            child: ChoiceCycler<CombatMode>(
              label: ref.t('ui.missions.prep.combat'),
              options: CombatMode.values,
              value: w.combatMode,
              display: (m) => m.label,
              onChanged: on,
              keyPrefix: 'prep-combat-mode-',
            ),
          );
    return RetroTooltip(
        key: const ValueKey('prep-combat-mode'),
        message: w.combatMode.tip,
        child: child);
  }

  Widget _header(Widget tabs) {
    final m = widget.members;
    return m == null
        ? tabs
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [m, tabs],
          );
  }

  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final tabs = [
      PanelTabSpec(
          ref.t('ui.missions.prep.tab'),
          ref.t('ui.missions.prep.tab_hint'),
          (_) => _missionTab()),
      ...w.shopTabs,
    ];
    final tab = tabs[_tab.clamp(0, tabs.length - 1)];
    final nReady = w.players.where((p) => p.ready).length;
    // Q / E, Ctrl+Tab y 1-5 cambian de pestaña (menu_focus.dart).
    return MenuTabKeys(
        count: tabs.length,
        index: _tab.clamp(0, tabs.length - 1),
        onChanged: (i) => setState(() => _tab = i),
        child: PanelFrame(
          title: ref.t('ui.missions.prep.title', {'name': w.mission.name}),
          width: 1000,
          fill: true,
          help: ref.t('ui.missions.prep.help'),
          titleTrailing: ProtoText(ref.t('ui.missions.prep.credits_ready', {
            'credits': w.credits,
            'ready': protoColor(
                nReady == w.players.length
                    ? ProtoColors.green
                    : ProtoColors.dim,
                ref.t('ui.missions.prep.ready_count',
                    {'ready': nReady, 'total': w.players.length})),
          })),
          header: _header(PanelTabs(
            labels: [for (final t in tabs) t.label],
            index: _tab,
            onChanged: (i) => setState(() => _tab = i),
          )),
          leading: [
            DsButton(ref.t('ui.missions.prep.cancel'),
                key: const ValueKey('prep-cancel'),
                kind: DsButtonKind.ghost,
                onPressed: w.onCancel),
          ],
          actions: [
            DsButton(ref.t('ui.missions.character'),
                key: const ValueKey('prep-character'),
                onPressed: w.onCharacter),
            // ¡LISTO! es la acción principal (borde y texto dorados).
            DsButton(
                ref.t(w.ready
                    ? 'ui.missions.prep.unready'
                    : 'ui.missions.prep.ready'),
                key: const ValueKey('prep-ready'),
                kind: w.ready ? DsButtonKind.secondary : DsButtonKind.primary,
                onPressed: () => w.onReady(!w.ready)),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PanelHint(tab.hint),
              Expanded(
                  child: KeyedSubtree(
                      key: ValueKey('prep-tab-$_tab'),
                      child: Builder(builder: tab.builder))),
            ],
          ),
        ));
  }

  Widget _missionTab() {
    final w = widget;
    final nReady = w.players.where((p) => p.ready).length;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: MissionCard(
                mission: w.mission, tier: w.tier, bossName: w.bossName),
          ),
        ),
        const SizedBox(width: 16),
        SizedBox(
          width: RetroType.width(context, 380),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                DsSectionHeader(ref.t('ui.missions.prep.group'),
                    key: const ValueKey('prep-group'),
                    trailing: Text(
                        ref.t('ui.missions.prep.ready_count',
                            {'ready': nReady, 'total': w.players.length}),
                        style: DsText.detail(nReady == w.players.length
                            ? DsColors.success
                            : DsColors.textSecondary))),
                // Una línea por jugador: estado, nombre y clase.
                for (final p in w.players)
                  Padding(
                    key: ValueKey('prep-player-${p.name}'),
                    padding: EdgeInsets.symmetric(
                        horizontal: DsSpace.md, vertical: DsSpace.xs),
                    child: ProtoText(
                      '${p.ready ? protoColor(DsColors.success, ref.t('ui.missions.prep.player_ready')) : protoColor(DsColors.textSecondary, ref.t('ui.missions.prep.player_preparing'))} '
                      '${protoColor(p.isLocal ? DsColors.selected : DsColors.textPrimary, protoEsc(p.name))} '
                      '${protoColor(DsColors.textSecondary, '${protoEsc(p.className)} Lv${p.level}')}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                SizedBox(height: DsSpace.sm),
                SectionPanel(
                  icon: PixelIconKind.sword,
                  title: ref.t('ui.missions.prep.your_gear'),
                  children: [

                    InfoLine(ref.t('ui.missions.prep.weapon'),
                        '<b style="color:#ff9f43">${protoEsc(w.weaponName)}</b>',
                        labelEms: 13),
                    InfoLine(ref.t('ui.missions.prep.consumables'),
                        ref.t('ui.missions.prep.consumables_value',
                            {'potions': w.potions, 'ethers': w.ethers}),
                        labelEms: 13),
                    InfoLine(ref.t('ui.missions.prep.turns'),
                        ref.t('ui.missions.prep.host_picks',
                            {'value': w.turnTimer.label}),
                        key: const ValueKey('prep-turn-timer'), labelEms: 13),
                    _combatModeLine(),
                    InfoLine(ref.t('ui.missions.prep.credits'), '<b>₵${w.credits}</b>',
                        labelEms: 13),
                  ],
                ),
                SectionPanel(
                  icon: PixelIconKind.lock,
                  color: ProtoColors.orange,
                  title: ref.t('ui.missions.prep.notice'),
                  children: [
                    ProtoText(protoColor(
                        ProtoColors.orange,
                        ref.t('ui.missions.prep.notice_text'))),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
