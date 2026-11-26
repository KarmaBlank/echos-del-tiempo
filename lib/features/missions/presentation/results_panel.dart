import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/design/ds_tokens.dart';
import '../../../app/theme/proto_colors.dart';

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
      {this.tooltip, this.exclusive = false});
  final String text;
  final FilterVerdict verdict;

  /// Ficha del objeto (markup).
  final String? tooltip;

  /// Legendario exclusivo de un Jefe del Abismo (se destaca aparte).
  final bool exclusive;
}

/// Pantalla de resultado de la misión (`#result` del prototipo): rango,
/// tiempo, XP, créditos, bonus y armas obtenidas. Ver
/// docs/specs/exploration.md § "Paneles".
class ResultsPanel extends ConsumerWidget {
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = result;
    final el = r.time.floor();
    final time = '${el ~/ 60}:${(el % 60).toString().padLeft(2, '0')}';
    final mine = r.drops[localId];
    Widget line(String s, {Color? color, Key? key}) => Padding(
          key: key,
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(retroText(s), style: TextStyle(color: color)),
        );
    const shadow = [
      Shadow(color: ProtoColors.titleShadow, offset: Offset(2, 2)),
    ];
    final progress = <Widget>[
      if (unlocked case final u?)
        Padding(
          key: const ValueKey('results-unlocked'),
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(retroText(u),
              style: TextStyle(
                  fontFamily: RetroType.titleFamily,
                  fontSize: RetroType.title,
                  color: DsColors.textTitle,
                  shadows: shadow)),
        ),
      if (othersUnlocked case final o?) line(o, color: ProtoColors.gold),
      if (trial case final t?)
        line(t,
            color: ProtoColors.violet, key: const ValueKey('results-trial')),
      if (ecoAtlas case final a?)
        line(a,
            color: kEcoColor,
            key: const ValueKey('results-atlas')),
      if (abyss case final a?)
        line(a,
            color: ProtoColors.violet,
            key: const ValueKey('results-abyss')),
    ];
    final exclusive = [for (final d in this.loot) if (d.exclusive) d];
    final loot = <Widget>[
      if (mine != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
              retroText(ref.t('ui.missions.results.you_got',
                  {'weapon': weaponName(mine)})),
              style: const TextStyle(color: DsColors.reward)),
        ),
      if (r.drops.isNotEmpty)
        line(
            r.drops.entries
                .map((e) => '${playerName(e.key)}: ${weaponName(e.value)}')
                .join(' · '),
            color: ProtoColors.dim),
      if (r.eliteDrops.isNotEmpty)
        line(
            ref.t('ui.missions.results.elites', {
              'n': r.elites,
              'drops': r.eliteDrops
                  .map((d) =>
                      '${playerName(d.playerId)}: ${weaponName(d.weaponId)}')
                  .join(' · '),
            }),
            color: ProtoColors.gold),
      if (exclusive.isNotEmpty)
        Container(
          key: const ValueKey('results-exclusive'),
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: ProtoColors.input,
            border: Border.all(color: ProtoColors.gold, width: 3),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(retroText(ref.t('ui.missions.results.abyss_exclusive')),
                  style: TextStyle(
                      fontFamily: RetroType.titleFamily,
                      fontSize: RetroType.title,
                      color: DsColors.textTitle,
                      shadows: shadow)),
              const SizedBox(height: 4),
              Wrap(spacing: 8, runSpacing: 8, children: [
                for (final d in exclusive)
                  LootLabel(
                      text: d.text,
                      verdict: d.verdict,
                      hiddenNote: ref.t('ui.missions.results.hidden_by_filter'),
                      tooltip: d.tooltip),
              ]),
            ],
          ),
        ),
      if (this.loot.isNotEmpty) ...[
        line(ref.t('ui.missions.results.your_drops', {'n': this.loot.length}),
            color: ProtoColors.gold),
        Wrap(
          key: const ValueKey('results-loot'),
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final d in this.loot)
              LootLabel(
                  text: d.text,
                  verdict: d.verdict,
                  hiddenNote: ref.t('ui.missions.results.hidden_by_filter'),
                  tooltip: d.tooltip),
          ],
        ),
      ],
    ];
    return PanelFrame(
      width: 900,
      title: ref.t(r.success
          ? 'ui.missions.results.success'
          : 'ui.missions.results.failure'),
      actions: [
        if (onAscend != null)
          PanelButton(ref.t('ui.missions.results.choose_ascension'),
              key: const ValueKey('results-ascend'),
              accent: ProtoColors.violet,
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
                color: ProtoColors.input,
                border: Border.all(color: ProtoColors.gold, width: 3),
              ),
              child: Text(retroText(ref.t('ui.missions.results.final_title')),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontFamily: RetroType.titleFamily,
                      fontSize: RetroType.title,
                      color: DsColors.textTitle,
                      shadows: shadow)),
            ),
            Text(retroText(ref.t('ui.missions.results.final_subtitle')),
                textAlign: TextAlign.center,
                style: const TextStyle(color: DsColors.textSubtitle)),
            const SizedBox(height: 8),
          ],
          // Qué misión: nombre y zona / piso.
          Text(retroText(r.missionName),
              style: const TextStyle(color: DsColors.textSubtitle)),
          if (zoneProgress case final z?)
            line(z,
                color: ProtoColors.dim, key: const ValueKey('results-zone')),
          const SizedBox(height: 6),
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
                            style: TextStyle(
                                fontFamily: RetroType.titleFamily,
                                fontSize: RetroType.display,
                                height: 1.4,
                                color: ProtoColors.gold,
                                shadows: const [
                                  Shadow(
                                      color: ProtoColors.titleShadow,
                                      offset: Offset(4, 4)),
                                ])),
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
          ),
          if (progress.isNotEmpty)
            SectionPanel(
                icon: PixelIconKind.arrowIn,
                title: ref.t('ui.missions.results.progress'),
                children: progress),
          if (loot.isNotEmpty)
            SectionPanel(
                icon: PixelIconKind.gem,
                title: ref.t('ui.missions.results.loot'),
                children: loot),
          Row(
            children: [
              Expanded(
                child: Text(
                    retroText(victoryLap
                        ? ref.t('ui.missions.results.lap_hint')
                        : ref.t('ui.missions.results.auto_return',
                            {'s': r.timeLeft.ceil()})),
                    key: const ValueKey('results-footer'),
                    style: const TextStyle(color: DsColors.textMuted)),
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
