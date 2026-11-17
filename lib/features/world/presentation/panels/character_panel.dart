import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/panel_frame.dart';
import '../../../../app/theme/retro_text.dart';
import '../../../../app/theme/retro_theme.dart';
import '../../../../game_engine/models/attributes.dart';
import '../../../../game_engine/models/game_session.dart';
import '../../../../game_engine/models/player_state.dart';
import '../session_controller.dart';
import '../session_view.dart';

/// Nombre y efecto de cada atributo (`STATN`, `STATD` del prototipo).
const kAttributeInfo = {
  Attribute.vit: ('VIT', 'Vitalidad', '+4 vida máx.'),
  Attribute.esp: ('ESP', 'Espíritu', '+1.5 maná y poder mágico'),
  Attribute.agi: ('AGI', 'Agilidad', '+0.5 velocidad: turnos más seguidos'),
  Attribute.fue: ('FUE', 'Fuerza', 'daño de armas pesadas'),
  Attribute.des: ('DES', 'Destreza', '+1.2% crítico, +0.1 velocidad, precisión'),
};

/// Panel de personaje (`char` del prototipo), versión mínima: resumen y
/// reparto de puntos. Árbol, armas y fusión son de la fase 5. Se abre
/// solo y no se puede cerrar mientras `mustAllocate` (subida de nivel).
class CharacterPanel extends StatefulWidget {
  const CharacterPanel(
      {super.key, required this.view, required this.controller});

  final SessionView view;
  final SessionController controller;

  @override
  State<CharacterPanel> createState() => _CharacterPanelState();
}

class _CharacterPanelState extends State<CharacterPanel> {
  final _alloc = <Attribute, int>{};

  int get _allocSum => _alloc.values.fold(0, (a, b) => a + b);

  @override
  Widget build(BuildContext context) {
    final view = widget.view;
    final me = view.me!;
    final prof = me.profile;
    final rules = widget.controller.engine.progression;
    final left = prof.points - _allocSum;
    final now = rules.derivedStats(prof);
    final next = _allocSum == 0 ? now : rules.previewAllocation(prof, _alloc);
    final must = view.mustAllocate;
    final cls = rules.catalog.classes[prof.classId]?.name ?? prof.classId;

    String row(String label, num a, num b) =>
        a == b ? '$label $a' : '$label $a → $b';

    return PanelFrame(
      title: must
          ? '¡SUBISTE A NIVEL ${prof.level}! Reparte tus puntos'
          : 'PERSONAJE',
      actions: [
        if (view.mode == SessionMode.prep)
          PanelButton('< VOLVER A PREPARACIÓN',
              onPressed: widget.controller.closePanel)
        else
          PanelButton('CERRAR [ESC]',
              onPressed: must ? null : widget.controller.closePanel),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(retroText('${prof.name} · $cls Lv${prof.level} · Puntos: $left'),
              style: const TextStyle(color: RetroPalette.gold)),
          const SizedBox(height: 16),
          for (final a in Attribute.values) _attrRow(a, prof.attributes[a], left),
          const SizedBox(height: 8),
          Text(retroText([
            row('HP', now.maxHp, next.maxHp),
            row('MP', now.maxMp, next.maxMp),
            row('ATQ', now.attack, next.attack),
            row('MAG', now.magic, next.magic),
            row('DEF', now.defense, next.defense),
            row('VEL', _one(now), _one(next)),
          ].join('   '))),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: [
              PanelButton('CONFIRMAR PUNTOS',
                  accent: RetroPalette.green,
                  onPressed: _allocSum == 0 ? null : _confirm),
            ],
          ),
          if (must) ...[
            const SizedBox(height: 8),
            const Text(
                'El equipo sigue cuando todos los que subieron de nivel '
                'confirmen sus puntos.',
                style: TextStyle(color: RetroPalette.muted)),
          ],
          const SizedBox(height: 8),
          const ComingSoon('Árbol de pasivas, armas y fusión'),
        ],
      ),
    );
  }

  double _one(DerivedStats d) => (d.speed * 10).roundToDouble() / 10;

  Widget _attrRow(Attribute a, int value, int left) {
    final (short, name, desc) = kAttributeInfo[a]!;
    final add = _alloc[a] ?? 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(width: 120, child: Text(retroText('$short $name'))),
          SizedBox(
            width: 72,
            child: Text('$value${add > 0 ? ' +$add' : ''}',
                style: TextStyle(
                    color: add > 0 ? RetroPalette.green : RetroPalette.ink)),
          ),
          PanelButton('-',
              key: ValueKey('dec-${a.name}'),
              onPressed: add > 0 ? () => setState(() => _alloc[a] = add - 1) : null),
          const SizedBox(width: 8),
          PanelButton('+',
              key: ValueKey('inc-${a.name}'),
              onPressed: left > 0 ? () => setState(() => _alloc[a] = add + 1) : null),
          const SizedBox(width: 16),
          Expanded(
            child: Text(retroText(desc),
                style: const TextStyle(color: RetroPalette.muted)),
          ),
        ],
      ),
    );
  }

  void _confirm() {
    final add = {
      for (final e in _alloc.entries)
        if (e.value > 0) e.key: e.value,
    };
    if (widget.controller.allocate(add)) setState(_alloc.clear);
  }
}
