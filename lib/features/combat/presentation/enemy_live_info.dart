import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../core/i18n/catalog_names.dart';
import '../../../core/i18n/data_text.dart';
import '../../../app/design/design.dart';
import '../../../app/theme/proto_markup.dart';
import '../../../app/theme/retro_text.dart';
import '../../../game_engine/data/enemies_catalog.dart';
import '../../../game_engine/models/battle_state.dart';
import '../../../game_engine/models/enemy_def.dart';
import '../../../game_engine/models/status.dart';
import '../../../game_engine/rules/battle_engine.dart';
import '../../../game_engine/rules/family_rules.dart';
import '../../../game_engine/rules/js_math.dart';
import '../../bestiary/domain/bestiary_text.dart' show familyTraitsMarkup;
import '../domain/skill_text.dart';
import 'combat_strings.dart';

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

  /// Tope absoluto por golpe de jefes y élites (combat.md § "Límites"),
  /// o vacío si no tiene.
  static String hitCapText(Strings s, Combatant e) {
    if (e.isPlayer || (!e.boss && !e.elite)) return '';
    final f = BattleEngine.absoluteHitCap(boss: e.boss, elite: e.elite);
    if (f <= 0 || f >= 1) return '';
    return s.t('ui.combat.enemy.hit_cap', {'pct': jsRound(f * 100)});
  }

  /// Tank and "nobody alone in one phase" (combat.md § "Tanques" and §
  /// "Nadie solo en una fase"), or empty.
  static String toughText(Strings s, Combatant e) {
    if (e.isPlayer) return '';
    final out = <String>[
      if (kEnemies[e.enemyType]?.tank ?? false) s.t('ui.combat.enemy.tank'),
      if (BattleEngine.phaseHold > 0)
        s.t('ui.combat.enemy.phase_hold',
            {'pct': jsRound(BattleEngine.phaseHold * 100)}),
    ];
    return out.join(' ');
  }

  /// Fuerza el pliegue (tests, capturas); `null` = sigue a Alt/Shift.
  final bool? open;

  /// "Quemadura ×3", "Mojado · 2 turnos", "Sagrado ×1 · 2 turnos".
  static List<String> statusLines(Strings s, Combatant e) =>
      [for (final (k, rest) in statusEntries(s, e)) '${k.tr}$rest'];

  /// Los estados de [e] en orden, con lo que sigue al nombre
  /// (" ×3", " · 2 turnos").
  static List<(StatusKind, String)> statusEntries(Strings s, Combatant e) => [
        for (final k in StatusKind.values)
          if (e.stacks(k) case final n when n > 0)
            (
              k,
              k.timed
                  ? ' · ${s.t('ui.combat.turns', {'n': n})}'
                  : ' ×$n'
                      '${k == StatusKind.holy && e.holyTurns > 0 ? ' · ${s.t('ui.combat.turns', {
                              'n': e.holyTurns
                            })}' : ''}'
            ),
      ];

  /// Qué hace la ULT [u] y cómo cancelarla (markup corto).
  static String ultDetail(Strings s, EnemyUltDef u) => [
        s.t(
            u.allTargets
                ? 'ui.combat.enemy.ult_power_all'
                : 'ui.combat.enemy.ult_power_one',
            {'x': fm(u.power)}),
        // Main status and secondary ones (e.g. a 30% stun on top).
        for (final st in [if (u.status != null) u.status!, ...u.extraStatuses])
          st.kind == StatusKind.stun
              // combat.md § "Control sobre jugadores".
              ? s.t('ui.combat.enemy.ult_break_fill', {
                  'pct':
                      st.chance == null ? '' : '${jsRound(st.chance! * 100)}%: '
                })
              : statusApplicationMarkup(st),
        if (u.delayAll > 0) s.t('ui.combat.enemy.ult_delay_all'),
        if (u.wipeBuffs) s.t('ui.combat.enemy.ult_wipe_buffs'),
        if (u.guaranteedCrit) s.t('ui.combat.enemy.ult_sure_crit'),
        s.t('ui.combat.enemy.ult_cancel'),
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
    final s = combatStrings(context);
    final open = widget.open ?? _keys;
    final ult = e.ultPending ? kEnemyUlts[e.ultId] : null;
    final mech = e.boss ? bossMechanicOf(kEnemies[e.enemyType]) : null;
    final states = EnemyLiveInfo.statusEntries(s, e);
    final aff = widget.affinities ? EnemyLiveInfo.affinityMarkup(e) : '';
    final cap = EnemyLiveInfo.hitCapText(s, e);
    final tough = EnemyLiveInfo.toughText(s, e);
    final sections = <Widget>[
      if (cap.isNotEmpty)
        Text(retroText(cap),
            key: const ValueKey('enemy-live-hitcap'),
            style: DsText.detail(DsColors.textSecondary)),
      if (tough.isNotEmpty)
        Text(retroText(tough),
            key: const ValueKey('enemy-live-tough'),
            style: DsText.detail(DsColors.textSecondary)),
      if (aff.isNotEmpty)
        ProtoText(aff,
            key: const ValueKey('enemy-live-affinity'), style: DsText.body()),
      if (ult != null)
        Column(
          key: const ValueKey('enemy-live-ult'),
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
                retroText(
                    s.t('ui.combat.enemy.ult_prepares', {'name': ult.tr})),
                style: DsText.body(DsColors.danger)),
            if (open)
              ProtoText(EnemyLiveInfo.ultDetail(s, ult),
                  key: const ValueKey('enemy-live-ult-detail'),
                  style: DsText.detail())
            else
              Text(retroText(s.t('ui.combat.enemy.what_it_does_hint')),
                  style: DsText.detail(DsColors.textSecondary)),
          ],
        ),
      if (mech != null)
        Column(
          key: const ValueKey('enemy-live-mech'),
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
                retroText(s.t('ui.combat.enemy.mechanic', {
                  'name': s.data(DataKeys.mechanicName(mech.id), mech.name)
                })),
                style: DsText.body(DsColors.warning)),
            if (open)
              ProtoText(s.data(DataKeys.mechanicCounter(mech.id), mech.counter),
                  style: DsText.detail())
            else
              Text(retroText(s.t('ui.combat.enemy.counter_hint')),
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
              Text(retroText(s.t('ui.combat.enemy.each_hint')),
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
