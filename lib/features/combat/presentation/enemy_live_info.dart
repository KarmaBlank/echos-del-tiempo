import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/design/design.dart';
import '../../../app/theme/proto_markup.dart';
import '../../../app/theme/retro_text.dart';
import '../../../game_engine/data/enemies_catalog.dart';
import '../../../game_engine/models/battle_state.dart';
import '../../../game_engine/models/enemy_def.dart';
import '../../../game_engine/models/status.dart';
import '../../../game_engine/rules/family_rules.dart';
import '../../../game_engine/rules/js_math.dart';
import '../../bestiary/domain/bestiary_text.dart' show familyTraitsMarkup;
import '../domain/skill_text.dart';

/// Estado en vivo del enemigo bajo el mouse, debajo de su ficha del
/// bestiario (battle_ui.md § "Tooltip del enemigo"): ULT que prepara,
/// mecánica del jefe y estados con nombre completo, con una línea del DS
/// entre secciones. Lo largo ("qué hace") va plegado: se ve con Alt o
/// Shift apretado (la ficha sigue al mouse y no recibe clics).
class EnemyLiveInfo extends StatefulWidget {
  const EnemyLiveInfo(
      {super.key, required this.enemy, this.open, this.affinities = false});

  final Combatant enemy;

  /// Muestra debilidades / resistencias / inmunidades de su familia
  /// (battle_attack_menu.md § 6: gratis, aunque el bestiario todavía no
  /// lo conozca). La batalla lo pide solo cuando la ficha dice "???".
  final bool affinities;

  /// Markup de las afinidades de [e], o vacío si su familia no tiene.
  static String affinityMarkup(Combatant e) {
    final r = familyRuleOf(e.enemyType);
    return r == null ? '' : familyTraitsMarkup(r);
  }

  /// Fuerza el pliegue (tests, capturas); `null` = sigue a Alt/Shift.
  final bool? open;

  /// "Quemadura ×3", "Mojado · 2 turnos", "Sagrado ×1 · 2 turnos".
  static List<String> statusLines(Combatant e) =>
      [for (final (k, rest) in statusEntries(e)) '${k.label}$rest'];

  /// Los estados de [e] en orden, con lo que sigue al nombre
  /// (" ×3", " · 2 turnos").
  static List<(StatusKind, String)> statusEntries(Combatant e) => [
        for (final k in StatusKind.values)
          if (e.stacks(k) case final n when n > 0)
            (
              k,
              k.timed
                  ? ' · $n ${n == 1 ? 'turno' : 'turnos'}'
                  : ' ×$n'
                      '${k == StatusKind.holy && e.holyTurns > 0 ? ' · ${e.holyTurns} turnos' : ''}'
            ),
      ];

  /// Qué hace la ULT [u] y cómo cancelarla (markup corto).
  static String ultDetail(EnemyUltDef u) => [
        'ATQ × ${fm(u.power)} ${u.allTargets ? 'a todo el grupo' : 'al objetivo'}',
        if (u.status case final st?) statusApplicationMarkup(st),
        if (u.delayAll > 0) 'Retrasa a todo el grupo',
        if (u.wipeBuffs) 'Borra los buffs del grupo',
        if (u.guaranteedCrit) 'Crítico seguro',
        'Cancelala: quebralo (barra QB) o drená su carga',
      ].join('<br>');

  @override
  State<EnemyLiveInfo> createState() => _EnemyLiveInfoState();
}

class _EnemyLiveInfoState extends State<EnemyLiveInfo> {
  bool _keys = false;

  bool _held() =>
      HardwareKeyboard.instance.isShiftPressed ||
      HardwareKeyboard.instance.isAltPressed;

  bool _onKey(KeyEvent _) {
    final h = _held();
    if (h != _keys && mounted) setState(() => _keys = h);
    return false;
  }

  @override
  void initState() {
    super.initState();
    _keys = _held();
    HardwareKeyboard.instance.addHandler(_onKey);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.enemy;
    final open = widget.open ?? _keys;
    final ult = e.ultPending ? kEnemyUlts[e.ultId] : null;
    final mech = e.boss ? bossMechanicOf(kEnemies[e.enemyType]) : null;
    final states = EnemyLiveInfo.statusEntries(e);
    final aff = widget.affinities ? EnemyLiveInfo.affinityMarkup(e) : '';
    final sections = <Widget>[
      if (aff.isNotEmpty)
        ProtoText(aff,
            key: const ValueKey('enemy-live-affinity'), style: DsText.body()),
      if (ult != null)
        Column(
          key: const ValueKey('enemy-live-ult'),
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(retroText('Prepara ${ult.name}: la lanza en su turno'),
                style: DsText.body(DsColors.danger)),
            if (open)
              ProtoText(EnemyLiveInfo.ultDetail(ult),
                  key: const ValueKey('enemy-live-ult-detail'),
                  style: DsText.detail())
            else
              Text(retroText('Qué hace: Alt / Shift'),
                  style: DsText.detail(DsColors.textSecondary)),
          ],
        ),
      if (mech != null)
        Column(
          key: const ValueKey('enemy-live-mech'),
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(retroText('Mecánica: ${mech.name}'),
                style: DsText.body(DsColors.warning)),
            if (open)
              ProtoText(mech.counter, style: DsText.detail())
            else
              Text(retroText('Cómo contrarrestarla: Alt / Shift'),
                  style: DsText.detail(DsColors.textSecondary)),
          ],
        ),
      if (states.isNotEmpty)
        Column(
          key: const ValueKey('enemy-live-status'),
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Uno por fila, con el nombre y color de todo el juego y su
            // pliegue (la flecha de DsFold): qué hace, con Alt / Shift
            // (la ficha sigue al mouse y no recibe clics).
            for (final (k, rest) in states)
              Column(
                key: ValueKey('enemy-live-status-${k.name}'),
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  ProtoText(
                      '${open ? 'v' : '>'} ${statusNameMarkup(k)}'
                      '${protoEsc(rest)}',
                      key: ValueKey('enemy-live-status-name-${k.name}'),
                      style: DsText.body()),
                  if (open)
                    Padding(
                      padding: EdgeInsets.only(left: DsSpace.md),
                      child: Text(retroText(statusDescriptionOf(k)),
                          key: ValueKey('enemy-live-status-desc-${k.name}'),
                          style: DsText.detail()),
                    ),
                ],
              ),
            if (!open)
              Text(retroText('Qué hace cada uno: Alt / Shift'),
                  style: DsText.detail(DsColors.textSecondary)),
          ],
        ),
    ];
    if (sections.isEmpty) return const SizedBox.shrink();
    return Column(
      key: const ValueKey('enemy-live'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final s in sections) ...[
          Container(
              height: 2,
              margin: EdgeInsets.symmetric(vertical: DsSpace.xs),
              color: DsColors.border),
          s,
        ],
      ],
    );
  }
}
