import 'package:material_ui/material_ui.dart';

import '../../../app/design/design.dart';
import '../../../app/theme/panel_frame.dart';
import '../../../app/theme/panel_widgets.dart';
import '../../../app/theme/retro_text.dart';
import '../../../app/theme/retro_theme.dart';
import '../../../game_engine/models/mission_def.dart';
import '../../../game_engine/rules/zone_rules.dart';
import '../../../app/widgets/menu_focus.dart';
import 'mission_card.dart';

/// Mostrador de misiones (`board` del prototipo) en lista + detalle: una
/// fila por zona / misión (rango, nombre y, a la derecha, el nivel o
/// "Bloqueada") y, a la derecha, la tarjeta de la elegida con objetivo,
/// recompensas y `PROPONER`. Ver docs/specs/panels.md § "Mostrador".
class MissionBoardPanel extends StatefulWidget {
  const MissionBoardPanel({
    super.key,
    required this.missions,
    required this.voteOpen,
    required this.onPropose,
    required this.onClose,
    this.onCharacter,
    this.bossName,
    this.playerLevel,
    this.zones,
    this.tutorial,
    this.lockText,
    this.tutorialDone = true,
  });

  /// Las 10 zonas con su estado para el jugador local
  /// (`ZoneRules.zoneList`). Con zonas, el mostrador lista las zonas en
  /// orden (las bloqueadas con su motivo en el detalle) y las
  /// "Próximamente" en gris. Sin zonas, una fila por misión.
  final List<ZoneStatus>? zones;

  final List<MissionDef> missions;

  /// Ya hay una votación en curso: no se puede proponer otra.
  final bool voteOpen;
  final ValueChanged<String> onPropose;
  final VoidCallback onClose;

  /// `Personaje [C]` (botones de abajo del prototipo, línea 1360).
  final VoidCallback? onCharacter;

  /// Nombre del jefe de una misión (para el objetivo).
  final String? Function(MissionDef m)? bossName;

  /// Nivel del jugador local.
  final int? playerLevel;

  /// TUTORIAL: Ecos de práctica, primera fila del sello
  /// (docs/specs/combat_tutorial.md § 1): su detalle. `null` = sin fila.
  final Widget? tutorial;

  /// La cuenta local ya lo hizo (la fila no se resalta).
  final bool tutorialDone;

  /// "Primero, todos tienen que hacer el TUTORIAL. Falta: …": las demás
  /// misiones salen desactivadas con este motivo (§ 2).
  final String? lockText;

  static const help = '<b>Mostrador</b><br>'
      'Propón una zona o misión: cuando todos votan SÍ, a prepararse.<br>'
      'Elige una misión y pulsa PROPONER: se abre una votación para todo el '
      'grupo.<br>'
      'Cuando <b>todos</b> votan SÍ pasan a la preparación (tienda, forja, '
      'equipo) y la misión empieza cuando todos marcan ¡LISTO!.<br>'
      'Es también el mapa de viaje: las zonas desbloqueadas se eligen '
      'acá (no hay mundo para caminar).<br>'
      '<span class="k">Rango</span>: S si terminas a tiempo sin K.O.; más '
      'rango = más créditos y más chance de arma.<br>'
      '<span class="k">Flechas / 1-9</span> eligen · '
      '<span class="k">Enter</span> elige · <span class="k">Esc</span> cierra.';

  @override
  State<MissionBoardPanel> createState() => _MissionBoardPanelState();
}

class _MissionBoardPanelState extends State<MissionBoardPanel> {
  String? _sel;

  static const _tutorialId = 'tutorial';

  /// Una fila `DsListRow` cuyo foco de teclado elige (el detalle sigue al
  /// cursor).
  Widget _focusRow({required String id, required Widget row}) => Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onFocusChange: (f) {
          if (f && _sel != id) setState(() => _sel = id);
        },
        child: row,
      );

  /// La fila TUTORIAL: Ecos de práctica (primera del sello).
  Widget _tutorialRow(bool selected) => _focusRow(
        id: _tutorialId,
        row: DsListRow(
          key: const ValueKey('mission-tutorial'),
          title: 'TUTORIAL: Ecos de práctica',
          titleColor: DsColors.reward,
          selected: selected,
          autofocus: selected,
          onTap: () => setState(() => _sel = _tutorialId),
          trailing: Text(widget.tutorialDone ? 'Hecho' : 'Pendiente',
              style: DsText.detail(widget.tutorialDone
                  ? DsColors.success
                  : DsColors.warning)),
        ),
      );

  /// (misión, zona) de cada fila elegible, en orden.
  List<(MissionDef, ZoneStatus?)> get _entries {
    final zs = widget.zones;
    if (zs == null) return [for (final m in widget.missions) (m, null)];
    return [
      for (final z in zs)
        if (z.mission case final m?) (m, z),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final entries = _entries;
    // Por defecto la última zona abierta (la más avanzada).
    final open = [
      for (final e in entries)
        if (e.$2 == null || e.$2!.open) e
    ];
    final sel = entries.where((e) => e.$1.id == _sel).firstOrNull ??
        (w.zones == null ? entries.firstOrNull : open.lastOrNull) ??
        entries.firstOrNull;
    // TUTORIAL (combat_tutorial.md § 1): primera fila; elegida por
    // defecto si falta hacerlo.
    final tutSel = w.tutorial != null &&
        (_sel == _tutorialId || (_sel == null && !w.tutorialDone));
    final list = <Widget>[
      if (w.tutorial != null) _tutorialRow(tutSel),
    ];
    if (w.zones case final zs?) {
      for (final z in zs) {
        final m = z.mission;
        if (m == null) {
          list.add(DsListRow(
            key: ValueKey('zone-soon-${z.zone.index}'),
            title: retroText('${z.zone.index} · ${z.zone.name}'),
            enabled: false,
            detail: retroText(z.label),
          ));
        } else {
          list.add(_row(m, z, !tutSel && m.id == sel?.$1.id));
        }
      }
    } else {
      for (final m in w.missions) {
        list.add(_row(m, null, !tutSel && m.id == sel?.$1.id));
      }
    }
    // 1-9 eligen la zona N; Q / E la anterior / siguiente.
    final idx =
        sel == null ? 0 : entries.indexWhere((e) => e.$1.id == sel.$1.id);
    return MenuTabKeys(
        count: entries.length,
        index: idx < 0 ? 0 : idx,
        onChanged: (i) => setState(() => _sel = entries[i].$1.id),
        child: PanelFrame(
          title: 'TABLERO DE ENCARGOS',
          width: 1000,
          fill: true,
          help: MissionBoardPanel.help,
          onClose: w.onClose,
          actions: [
            if (w.onCharacter != null)
              DsButton('PERSONAJE [C]',
                  key: const ValueKey('board-character'),
                  onPressed: w.onCharacter),
            DsButton('CERRAR [ESC]',
                key: const ValueKey('board-close'), onPressed: w.onClose),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: PanelSplit(
                  listWidth: 340,
                  list: [
                    NavSection(
                        child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: list)),
                  ],
                  detail: tutSel
                      ? PanelDetail(children: [
                          SizedBox(height: 420, child: w.tutorial),
                        ])
                      : sel == null
                      ? const PanelDetail(children: [])
                      : _detail(sel.$1, sel.$2),
                ),
              ),
            ],
          ),
        ));
  }

  /// Fila de una línea (`DsListRow`): rango, zona / misión y, a la
  /// derecha, el nivel o "Bloqueada" (el motivo, en el detalle).
  Widget _row(MissionDef m, ZoneStatus? z, bool selected) {
    final locked = z != null && !z.open;
    final low =
        widget.playerLevel != null && widget.playerLevel! < m.recommendedLevel;
    final name = z == null ? m.name : '${z.zone.index} · ${z.zone.name}';
    return _focusRow(
      id: m.id,
      row: DsListRow(
        key: ValueKey('mission-${m.id}'),
        title: retroText(name),
        titleColor: locked ? DsColors.textDisabled : null,
        selected: selected,
        autofocus: selected,
        onTap: () => setState(() => _sel = m.id),
        leading: Text(m.rank, style: DsText.subtitle(DsColors.warning)),
        trailing: Text(
            locked ? 'Bloqueada' : 'Lv ${m.recommendedLevel}',
            style: DsText.detail(locked
                ? DsColors.textSecondary
                : low
                    ? DsColors.danger
                    : DsColors.success)),
      ),
    );
  }

  Widget _detail(MissionDef m, ZoneStatus? z) {
    final w = widget;
    final locked = z != null && !z.open;
    // TUTORIAL pendiente en la sala (combat_tutorial.md § 2).
    final reason = w.lockText ??
        (locked
            ? 'Bloqueada'
            : w.voteOpen
                ? 'Ya hay una votación'
                : null);
    return PanelDetail(
      footer: [
        // Por qué no se puede: una línea a la izquierda de PROPONER (y en
        // su tooltip).
        if (reason != null)
          ConstrainedBox(
            constraints:
                BoxConstraints(maxWidth: RetroType.width(context, 420)),
            child: Text(retroText(reason),
                key: ValueKey('propose-reason-${m.id}'),
                maxLines: 2,
                textAlign: TextAlign.right,
                style: DsText.detail(DsColors.danger)),
          ),
        DsButton('PROPONER',
            key: ValueKey('propose-${m.id}'),
            kind: DsButtonKind.primary,
            tooltip: reason,
            onPressed: reason == null ? () => w.onPropose(m.id) : null),
      ],

      children: [
        MissionCard(
          key: ValueKey('mission-card-${m.id}'),
          mission: m,
          tier: w.missions.indexOf(m) + 1,
          bossName: w.bossName?.call(m),
          playerLevel: w.playerLevel,
          zone: z,
        ),
      ],
    );
  }
}
