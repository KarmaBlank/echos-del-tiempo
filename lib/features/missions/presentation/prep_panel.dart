import 'package:material_ui/material_ui.dart';

import '../../../app/theme/panel_frame.dart';
import '../../../app/theme/panel_widgets.dart';
import '../../../app/design/design.dart';
import '../../../app/theme/proto_colors.dart';

import '../../../app/theme/proto_markup.dart';
import '../../../app/theme/retro_theme.dart';
import '../../../game_engine/models/mission_def.dart';
import '../../../game_engine/models/turn_timer.dart';
import '../../../app/widgets/menu_focus.dart';
import '../../../app/widgets/menu_widgets.dart';
import '../../../app/widgets/pixel_icon.dart';
import '../../../app/widgets/section_panel.dart';
import 'mission_card.dart';

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
class PrepPanel extends StatefulWidget {
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
    this.members,
  });

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

  static const help = '<b>Preparación</b><br>'
      'Último paso antes de salir: compra, mejora y equípate. Dentro de la '
      'misión no hay tienda ni cambio de arma.<br>'
      'La misión empieza cuando <b>todos</b> marcan ¡LISTO!. CANCELAR MISIÓN '
      'vuelve al lobby a todo el grupo.';

  @override
  State<PrepPanel> createState() => _PrepPanelState();
}

class _PrepPanelState extends State<PrepPanel> {
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
          'MISIÓN',
          'Revisa la misión y tu equipo. Cuando estés, '
              'marca ¡LISTO!.',
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
          title: 'PREPARACIÓN · ${w.mission.name}',
          width: 1000,
          fill: true,
          help: PrepPanel.help,
          titleTrailing: ProtoText('Créditos <b>₵${w.credits}</b> · '
              '${protoColor(nReady == w.players.length ? ProtoColors.green : ProtoColors.dim, '$nReady/${w.players.length} listos')}'),
          header: _header(PanelTabs(
            labels: [for (final t in tabs) t.label],
            index: _tab,
            onChanged: (i) => setState(() => _tab = i),
          )),
          leading: [
            DsButton('CANCELAR MISIÓN',
                key: const ValueKey('prep-cancel'),
                kind: DsButtonKind.ghost,
                onPressed: w.onCancel),
          ],
          actions: [
            DsButton('PERSONAJE [C]',
                key: const ValueKey('prep-character'),
                onPressed: w.onCharacter),
            // ¡LISTO! es la acción principal (borde y texto dorados).
            DsButton(w.ready ? 'YA NO ESTOY LISTO' : '¡LISTO!',
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
                DsSectionHeader('GRUPO',
                    key: const ValueKey('prep-group'),
                    trailing: Text('$nReady/${w.players.length} listos',
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
                      '${p.ready ? protoColor(DsColors.success, 'LISTO') : protoColor(DsColors.textSecondary, 'preparando...')} '
                      '${protoColor(p.isLocal ? DsColors.selected : DsColors.textPrimary, protoEsc(p.name))} '
                      '${protoColor(DsColors.textSecondary, '${protoEsc(p.className)} Lv${p.level}')}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                SizedBox(height: DsSpace.sm),
                SectionPanel(
                  icon: PixelIconKind.sword,
                  title: 'TU EQUIPO',
                  children: [

                    InfoLine('Arma',
                        '<b style="color:#ff9f43">${protoEsc(w.weaponName)}</b>',
                        labelEms: 13),
                    InfoLine('Consumibles',
                        'Pociones x${w.potions} · Éteres x${w.ethers}',
                        labelEms: 13),
                    InfoLine('Turnos',
                        '${w.turnTimer.label} <span class="k">· lo elige el anfitrión</span>',
                        key: const ValueKey('prep-turn-timer'), labelEms: 13),
                    InfoLine('Créditos', '<b>₵${w.credits}</b>', labelEms: 13),
                  ],
                ),
                SectionPanel(
                  icon: PixelIconKind.lock,
                  color: ProtoColors.orange,
                  title: 'AVISO',
                  children: [
                    ProtoText(protoColor(
                        ProtoColors.orange,
                        '<b>En la misión no hay tienda ni cambio de arma</b>: '
                        'solo subes de nivel.')),
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
