import 'package:material_ui/material_ui.dart';

import '../../../app/theme/panel_frame.dart';
import '../../../app/theme/panel_widgets.dart';
import '../../../app/theme/proto_colors.dart';
import '../../../app/theme/proto_markup.dart';
import '../../../app/theme/retro_text.dart';
import '../../../app/theme/retro_theme.dart';
import '../../../game_engine/models/mission_def.dart';
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
  });

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
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final w = widget;
    final tabs = [
      PanelTabSpec('MISIÓN', 'Revisa la misión y tu equipo. Cuando estés, '
          'marca ¡LISTO!.', (_) => _missionTab()),
      ...w.shopTabs,
    ];
    final tab = tabs[_tab.clamp(0, tabs.length - 1)];
    final nReady = w.players.where((p) => p.ready).length;
    return PanelFrame(
      title: 'PREPARACIÓN · ${w.mission.name}',
      width: 1000,
      fill: true,
      help: PrepPanel.help,
      titleTrailing: ProtoText('Créditos <b>₵${w.credits}</b> · '
          '${protoColor(nReady == w.players.length ? ProtoColors.green : ProtoColors.dim, '$nReady/${w.players.length} listos')}'),
      header: PanelTabs(
        labels: [for (final t in tabs) t.label],
        index: _tab,
        onChanged: (i) => setState(() => _tab = i),
      ),
      leading: [
        PanelButton('CANCELAR MISIÓN',
            key: const ValueKey('prep-cancel'), onPressed: w.onCancel),
      ],
      actions: [
        PanelButton('PERSONAJE [C]',
            key: const ValueKey('prep-character'), onPressed: w.onCharacter),
        PanelButton(w.ready ? 'YA NO ESTOY LISTO' : '¡LISTO!',
            key: const ValueKey('prep-ready'),
            accent: w.ready ? null : RetroPalette.green,
            selected: !w.ready,
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
    );
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
          width: 360,
          child: PanelDetail(
            children: [
              Text(retroText('GRUPO · $nReady/${w.players.length} listos'),
                  style: const TextStyle(color: ProtoColors.gold)),
              const SizedBox(height: 4),
              for (final p in w.players)
                ProtoText(
                  key: ValueKey('prep-player-${p.name}'),
                  '${p.ready ? protoColor(ProtoColors.green, 'LISTO') : protoColor(ProtoColors.dim, 'preparando...')} '
                  '${p.isLocal ? '<b>${protoEsc(p.name)}</b>' : protoEsc(p.name)} '
                  '<small>${protoEsc(p.className)} Lv${p.level}</small>',
                ),
              const SizedBox(height: 12),
              const Text('TU EQUIPO', style: TextStyle(color: ProtoColors.gold)),
              const SizedBox(height: 4),
              ProtoText('Arma: <b style="color:#ff9f43">'
                  '${protoEsc(w.weaponName)}</b>'),
              ProtoText('Pociones x${w.potions} · Éteres x${w.ethers}'),
              ProtoText('Créditos <b>₵${w.credits}</b>'),
              const SizedBox(height: 12),
              ProtoText(protoColor(ProtoColors.orange,
                  '<b>En la misión no hay tienda ni cambio de arma</b>: '
                  'solo subes de nivel.')),
            ],
          ),
        ),
      ],
    );
  }
}
