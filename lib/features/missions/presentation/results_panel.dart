import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/design/design.dart';
import '../../../app/theme/proto_markup.dart';

import '../../../app/theme/panel_frame.dart';
import '../../../app/theme/retro_text.dart';
import '../../../app/theme/retro_theme.dart';
import '../../../game_engine/models/game_session.dart';
import '../../../game_engine/models/loot_filter.dart';
import '../../../app/widgets/menu_focus.dart';
import '../../../app/widgets/menu_widgets.dart';
import '../../../app/widgets/pixel_icon.dart';
import '../../../app/widgets/section_panel.dart';
import '../../inventory/presentation/item_widgets.dart' hide PixelIcon;
import '../../../core/i18n/i18n_providers.dart';

/// Un drop propio de la misión con el veredicto de tu filtro.
class ResultDrop {
  const ResultDrop(this.text, this.verdict,
      {this.tooltip, this.exclusive = false, this.cell});
  final String text;

  /// The INVENTARIO cell of the drop at side `size` (its sprite, framed
  /// when `selected`); `null`
  /// = a generic gem cell.
  final Widget Function(double size, bool selected)? cell;
  final FilterVerdict verdict;

  /// Ficha del objeto (markup).
  final String? tooltip;

  /// Legendario exclusivo de un Jefe del Abismo (se destaca aparte).
  final bool exclusive;
}

/// Pantalla de resultado de la misión (`#result` del prototipo): rango,
/// tiempo, XP, créditos, bonus y armas obtenidas. Subtabs RESUMEN /
/// PROGRESO / BOTÍN (never stacked sections); BOTÍN is the INVENTARIO
/// grid with the chosen drop on the right. Ver docs/specs/panels.md §
/// "Resultado" y design_system.md § DsGridDetailLayout.
class ResultsPanel extends ConsumerStatefulWidget {
  const ResultsPanel({
    super.key,
    required this.result,
    required this.localId,
    required this.playerName,
    required this.weaponName,
    required this.onBack,
    this.loot = const [],
    this.zoneProgress,
    this.unlocked,
    this.othersUnlocked,
    this.finalVictory = false,
    this.ecoAtlas,
    this.trial,
    this.onAscend,
    this.abyss,
    this.victoryLap = false,
  });

  /// Victoria v0.20.22: la ventana se cierra y el grupo sigue en el mapa
  /// hasta que todos tocan LISTO (sin regreso automático).
  final bool victoryLap;

  /// Jefe del Abismo vencido: `X vencido: +2 puntos de Atlas`
  /// (docs/specs/abyss_bosses.md § 4).
  final String? abyss;

  /// Prueba del Tiempo superada: `+2 puntos de ascensión` (o que ya la
  /// tenías). Ver docs/specs/ascension.md § 1.2.
  final String? trial;

  /// ELEGIR ASCENSIÓN (con la Prueba I y todavía sin ascensión).
  final VoidCallback? onAscend;

  /// Eco: lo que ganó tu Atlas (`+3 puntos de Atlas: tier 5, zona, jefe`)
  /// o que no hubo primeras veces (docs/specs/ecos_atlas.md § 5.1).
  final String? ecoAtlas;

  /// Se venció al jefe final (zona 10): cartel `¡Venciste al Devorador de
  /// Eras!` (panels.md § "Final (v0.3.0)").
  final bool finalVictory;

  /// Si [r] es la victoria final: misión ganada de la zona 10 (el motor
  /// no tiene otra señal; el jefe de la zona 10 es el Devorador).
  static bool isFinalVictory(MissionResult r) =>
      r.success &&
      r.zone == 10 &&
      r.missionId != 'eco' &&
      r.missionId != 'trial' &&
      r.missionId != 'abismo';

  /// `Zona 2 · Bosque Hondo · Piso 3/3` (misiones de zona).
  final String? zoneProgress;

  /// `¡Zona 3 desbloqueada! Ruinas Cronales` si el jugador local
  /// desbloqueó una zona.
  final String? unlocked;

  /// Los demás jugadores que desbloquearon (`Bo: Zona 3`).
  final String? othersUnlocked;

  /// Tus drops de la misión (loot v2), con el estilo de tu filtro.
  final List<ResultDrop> loot;

  final MissionResult result;
  final String localId;
  final String Function(String playerId) playerName;
  final String Function(String weaponId) weaponName;
  final VoidCallback onBack;

  static String rankLabel(MissionRank r) => r.name.toUpperCase();

  /// Fixed height of the tab body (the grid scrolls inside).
  static const bodyHeight = 300.0;

  @override
  ConsumerState<ResultsPanel> createState() => _ResultsPanelState();
}

class _ResultsPanelState extends ConsumerState<ResultsPanel> {
  int _tab = 0;
  int _sel = 0;

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final unlocked = w.unlocked,
        othersUnlocked = w.othersUnlocked,
        trial = w.trial,
        ecoAtlas = w.ecoAtlas,
        abyss = w.abyss,
        finalVictory = w.finalVictory,
        zoneProgress = w.zoneProgress,
        onAscend = w.onAscend,
        victoryLap = w.victoryLap,
        onBack = w.onBack,
        playerName = w.playerName,
        weaponName = w.weaponName;
    String rankLabel(MissionRank r) => ResultsPanel.rankLabel(r);
    final r = w.result;
    final el = r.time.floor();
    final time = '${el ~/ 60}:${(el % 60).toString().padLeft(2, '0')}';
    final mine = r.drops[w.localId];
    Widget line(String s, {Color? color, Key? key}) => Padding(
          key: key,
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(retroText(s), style: DsText.body(color)),
        );
    final progress = <Widget>[
      if (unlocked case final u?)
        Padding(
          key: const ValueKey('results-unlocked'),
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(retroText(u),
              style: DsText.title(DsColors.reward)),
        ),
      if (othersUnlocked case final o?) line(o, color: DsColors.reward),
      if (trial case final t?)
        line(t,
            color: DsColors.pulse, key: const ValueKey('results-trial')),
      if (ecoAtlas case final a?)
        line(a,
            color: kEcoColor,
            key: const ValueKey('results-atlas')),
      if (abyss case final a?)
        line(a,
            color: DsColors.pulse,
            key: const ValueKey('results-abyss')),
    ];
    // Exclusive Abyss legendaries first (gold frame), then the rest.
    final drops = [
      for (final d in w.loot)
        if (d.exclusive) d,
      for (final d in w.loot)
        if (!d.exclusive) d,
    ];
    final weapons = <Widget>[
      if (mine != null)
        line(
            ref.t('ui.missions.results.you_got', {'weapon': weaponName(mine)}),
            color: DsColors.reward),
      if (r.drops.isNotEmpty)
        line(
            r.drops.entries
                .map((e) => '${playerName(e.key)}: ${weaponName(e.value)}')
                .join(' · '),
            color: DsColors.textSecondary),
      if (r.eliteDrops.isNotEmpty)
        line(
            ref.t('ui.missions.results.elites', {
              'n': r.elites,
              'drops': r.eliteDrops
                  .map((d) =>
                      '${playerName(d.playerId)}: ${weaponName(d.weaponId)}')
                  .join(' · '),
            }),
            color: DsColors.reward),
    ];
    final hasLoot = drops.isNotEmpty || weapons.isNotEmpty;
    final tabs = <(String, String)>[
      ('summary', ref.t('ui.missions.results.tab_summary')),
      if (progress.isNotEmpty)
        ('progress', ref.t('ui.missions.results.progress')),
      if (hasLoot) ('loot', ref.t('ui.missions.results.loot')),
    ];
    final tab = tabs[_tab.clamp(0, tabs.length - 1)].$1;
    final sel = drops.isEmpty ? null : drops[_sel.clamp(0, drops.length - 1)];
    final hidden = ref.t('ui.missions.results.hidden_by_filter');
    Widget dropCell(BuildContext context, int i, double size) {
      final d = drops[i];
      final cell = d.cell?.call(size, d == sel) ??
          DsItemCell(
              dimension: size,
              icon: PixelIcon(PixelIconKind.gem,
                  size: DsSizes.itemIcon * size / DsSizes.itemCell,
                  color: d.verdict.style.textColor == null
                      ? DsColors.textPrimary
                      : RarityColors.filterColor(d.verdict.style.textColor!)),
              border: d.exclusive ? DsColors.reward : DsColors.border,
              selected: d == sel);
      return DsTooltip(
        card: DsTooltipCard(title: d.text, children: [
          if (!d.verdict.visible) Text(hidden, style: DsText.detail()),
          if (d.exclusive)
            Text(ref.t('ui.missions.results.abyss_exclusive'),
                style: DsText.detail(DsColors.reward)),
        ]),
        child: GestureDetector(
          key: ValueKey('results-drop-$i'),
          behavior: HitTestBehavior.opaque,
          onTap: () => setState(() => _sel = i),
          child: Opacity(opacity: d.verdict.visible ? 1 : 0.4, child: cell),
        ),
      );
    }

    final lootTab = DsGridDetailLayout(
      key: const ValueKey('results-loot'),
      keyPrefix: 'results',
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ...weapons,
          if (drops.isNotEmpty)
            Text(
                retroText(ref.t('ui.missions.results.your_drops',
                    {'n': drops.length})),
                style: DsText.subtitle(DsColors.reward)),
        ],
      ),
      count: drops.length,
      empty: Text(ref.t('ui.missions.results.loot_empty'),
          style: DsText.detail()),
      cell: dropCell,
      detail: sel == null
          ? null
          : DsDetailPane(
              key: const ValueKey('results-drop-detail'),
              body: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (sel.exclusive)
                    Padding(
                      key: const ValueKey('results-exclusive'),
                      padding: EdgeInsets.only(bottom: DsSpace.xs),
                      child: DsTag(ref.t('ui.missions.results.abyss_exclusive'),
                          color: DsColors.reward),
                    ),
                  LootLabel(
                      text: sel.text,
                      verdict: sel.verdict,
                      hiddenNote: hidden,
                      tooltip: null),
                  if (sel.tooltip case final t?) ...[
                    SizedBox(height: DsSpace.sm),
                    ProtoText(t),
                  ],
                ],
              ),
            ),
    );
    Widget summary() =>
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: RetroType.width(context, 260),
                  child: SectionPanel(
                    icon: PixelIconKind.star,
                    title: ref.t('ui.missions.results.rank'),
                    children: [
                      Center(
                        child: Text(rankLabel(r.rank),
                            key: const ValueKey('results-rank'),
                            style: DsText.display(DsColors.reward)),
                      ),
                      InfoLine(ref.t('ui.missions.results.time'), time, labelEms: 8),
                      InfoLine(ref.t('ui.missions.results.kos'), '${r.kos}', labelEms: 8),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: SectionPanel(
                    icon: PixelIconKind.coin,
                    title: ref.t('ui.missions.rewards'),
                    children: [
                      InfoLine(ref.t('ui.missions.results.xp'), '<b>+${r.xp}</b>',
                          labelEms: 21),
                      InfoLine(ref.t('ui.missions.results.fight_credits'),
                          '<b>₵${r.credits}</b>',
                          labelEms: 21),
                      InfoLine(
                          ref.t('ui.missions.results.rank_bonus',
                              {'rank': rankLabel(r.rank)}),
                          '<b>+₵${r.bonus}</b> '
                              '<span class="k">(${(r.bonusPercent * 100).round()}%)</span>',
                          labelEms: 21),
                    ],
                  ),
                ),
              ],
            ),
          );
    return PanelFrame(
      width: 1000,
      title: ref.t(r.success
          ? 'ui.missions.results.success'
          : 'ui.missions.results.failure'),
      actions: [
        if (onAscend != null)
          PanelButton(ref.t('ui.missions.results.choose_ascension'),
              key: const ValueKey('results-ascend'),
              accent: DsColors.pulse,
              onPressed: onAscend),
        // Abre con el foco en el primario: Enter = volver.
        InitialFocus(
          child: PanelButton(
              ref.t(victoryLap
                  ? 'ui.missions.results.close'
                  : 'ui.missions.results.back_to_lobby'),
              key: const ValueKey('results-back'), onPressed: onBack),
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (finalVictory) ...[
            Container(
              key: const ValueKey('results-final'),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: DsColors.surfaceSunken,
                border: Border.all(color: DsColors.reward, width: 3),
              ),
              child: Text(retroText(ref.t('ui.missions.results.final_title')),
                  textAlign: TextAlign.center,
                  style: DsText.title(DsColors.reward)),
            ),
            Text(retroText(ref.t('ui.missions.results.final_subtitle')),
                textAlign: TextAlign.center,
                style: DsText.body(DsColors.mp)),
            const SizedBox(height: 8),
          ],
          // Qué misión: nombre y zona / piso.
          Text(retroText(r.missionName),
              style: DsText.body(DsColors.mp)),
          if (zoneProgress case final z?)
            line(z,
                color: DsColors.textSecondary, key: const ValueKey('results-zone')),
          SizedBox(height: DsSpace.sm),
          if (tabs.length > 1) ...[
            DsTabBar(
              key: const ValueKey('results-tabs'),
              tabs: [
                for (final t in tabs)
                  DsTab(t.$2, key: ValueKey('results-tab-${t.$1}')),
              ],
              index: _tab.clamp(0, tabs.length - 1),
              onChanged: (i) => setState(() => _tab = i),
            ),
            SizedBox(height: DsSpace.sm),
          ],
          SizedBox(
            height: ResultsPanel.bodyHeight,
            child: switch (tab) {
              'progress' => SingleChildScrollView(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: progress)),
              'loot' => lootTab,
              _ => SingleChildScrollView(child: summary()),
            },
          ),
          SizedBox(height: DsSpace.sm),
          Row(
            children: [
              Expanded(
                child: Text(
                    retroText(victoryLap
                        ? ref.t('ui.missions.results.lap_hint')
                        : ref.t('ui.missions.results.auto_return',
                            {'s': r.timeLeft.ceil()})),
                    key: const ValueKey('results-footer'),
                    style: DsText.body(DsColors.textSecondary)),
              ),
              KeyHints(
                  confirm: ref.t(victoryLap
                      ? 'ui.missions.results.hint_close'
                      : 'ui.missions.results.hint_lobby'),
                  back: null),
            ],
          ),
        ],
      ),
    );
  }
}
