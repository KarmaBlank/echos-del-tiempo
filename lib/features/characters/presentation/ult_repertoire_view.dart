import 'package:material_ui/material_ui.dart';

import '../../../app/design/design.dart';
import '../../../app/theme/proto_markup.dart';
import '../../../game_engine/data/achievements_catalog.dart';
import '../../../game_engine/data/classes_catalog.dart';
import '../../../game_engine/data/enemies_catalog.dart';
import '../../../game_engine/data/uniques_catalog.dart';
import '../../../game_engine/data/ults_v2_catalog.dart';
import '../../../game_engine/models/item.dart';
import '../../../game_engine/models/player_profile.dart';
import '../../../game_engine/models/ult_def.dart';
import '../../../game_engine/models/weapon.dart';
import '../../../game_engine/rules/ult_rules.dart';
import '../../combat/domain/skill_text.dart';

/// Pestaña ULT de PERSONAJE (docs/specs/ultimates_v2.md § 2.1 y § 2.4):
/// elegir la ULT activa del repertorio, mejorarla (nivel, próximo efecto,
/// costo y MEJORAR con confirmación) y ver las 50 con su fuente.
class UltRepertoireView extends StatefulWidget {
  const UltRepertoireView({
    super.key,
    required this.profile,
    required this.weapon,
    required this.item,
    required this.editable,
    required this.onSelect,
    required this.onUpgrade,
  });

  final PlayerProfile profile;
  final WeaponDef weapon;
  final ItemInstance? item;

  /// Fuera de combate (pueblo o campamento).
  final bool editable;
  final bool Function(String? id) onSelect;
  final bool Function(String id) onUpgrade;

  static const help = '<b>ULT</b><br>'
      'Tu repertorio: toda ULT que conseguís queda para siempre, también '
      'la de un arma (aunque la vendas o la desarmes). Elegí la activa '
      'fuera de combate; se usa con cualquier arma del tipo compatible.<br>'
      'MEJORAR sube su nivel (1 a 5) con créditos y materiales.';

  @override
  State<UltRepertoireView> createState() => _UltRepertoireViewState();
}

class _UltRepertoireViewState extends State<UltRepertoireView> {
  String? _focus;
  bool _confirm = false;

  String _name(String id) =>
      kUniques[id]?.name ??
      kAchievementsById[id]?.name ??
      kEnemies[id]?.name ??
      kClasses[id]?.name ??
      id;

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    final opts = UltRules.optionsOf(p, widget.weapon, widget.item);
    final active = UltRules.validSel(p, widget.weapon, widget.item);
    final shown = active ??
        opts
            .where((o) => o.kind != UltOptionKind.learned || o.available)
            .firstOrNull
            ?.id;
    final focus = opts.where((o) => o.id == (_focus ?? shown)).firstOrNull;
    final known = {...p.ultKnown, ...UltRules.earned(p)};
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DsSectionHeader('ULT ACTIVA',
              trailing: Text(
                  p.ultSel == null
                      ? 'Automática'
                      : active == null
                          ? 'No compatible con tu arma: se usa la automática'
                          : 'Elegida',
                  style: DsText.detail())),
          if (focus != null) ...[
            _detail(focus),
            SizedBox(height: DsSpace.sm),
          ],
          // La activa primero; después el resto (las grises al final).
          for (final o in [
            ...opts.where((o) => o.id == (active ?? shown)),
            ...opts.where((o) => o.id != (active ?? shown) && o.available),
            ...opts.where((o) => o.id != (active ?? shown) && !o.available),
          ])
            _row(o, active, shown),
          SizedBox(height: DsSpace.md),
          DsSectionHeader('LAS 50 ULT',
              trailing: Text(
                  '${kUltV2List.where((u) => known.contains(u.id)).length}/50',
                  style: DsText.detail())),
          for (final s in UltSource.values) ...[
            Padding(
              padding: EdgeInsets.only(top: DsSpace.sm),
              child: Text(s.label.toUpperCase(), style: DsText.subtitle()),
            ),
            for (final u in kUltV2List.where((u) => u.source == s))
              DsListRow(
                compact: true,
                title: known.contains(u.id)
                    ? '${u.name} · Nv ${UltRules.levelOf(p, u.id)}'
                    : u.name,
                titleColor: known.contains(u.id) ? null : DsColors.textSecondary,
                detail: '${known.contains(u.id) ? 'Obtenida' : 'Falta'} · '
                    '${ultHowText(u, name: _name)}',
              ),
          ],
        ],
      ),
    );
  }

  Widget _row(UltOption o, String? active, String? shown) {
    final isActive = o.id == (active ?? shown);
    final lv = o.kind == UltOptionKind.learned ? ' · Nv ${o.level}' : '';
    final kind = switch (o.kind) {
      UltOptionKind.ascension => 'Ascensión',
      UltOptionKind.weaponType => 'Del tipo de arma',
      UltOptionKind.learned => o.def?.source.label ?? 'De arma',
    };
    return DsListRow(
      compact: true,
      title: '${o.skill.name}$lv · ${o.skill.ultCost}',
      detail: o.reason == null ? kind : '$kind · ${o.reason}',
      titleColor: o.available ? null : DsColors.textSecondary,
      selected: o.id == _focus,
      onTap: () => setState(() {
        _focus = o.id;
        _confirm = false;
      }),
      trailing: isActive
          ? const DsBadge('ACTIVA')
          : DsButton('ELEGIR',
              size: DsButtonSize.compact,
              onPressed: widget.editable && o.available
                  ? () => widget.onSelect(o.id)
                  : null),
    );
  }

  Widget _detail(UltOption o) {
    final p = widget.profile;
    final learned = o.kind == UltOptionKind.learned;
    final lv = learned ? UltRules.levelOf(p, o.id) : 1;
    final cost = learned ? UltRules.upgradeCost(o.id, lv) : null;
    final affordable = cost != null &&
        p.credits >= cost.credits &&
        cost.materials.entries.every((e) => p.material(e.key) >= e.value);
    return DsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProtoText(describeSkillMarkup(UltRules.leveled(o.skill, lv), null,
              ultimate: true)),
          if (learned) ...[
            SizedBox(height: DsSpace.sm),
            Text(
                'Nivel $lv/${UltRules.maxLevel}: poder ×'
                '${UltRules.levelFactor(lv).toStringAsFixed(2)}',
                style: DsText.body()),
            if (cost != null) ...[
              Text(
                  'Próximo nivel ${lv + 1}: poder ×'
                  '${UltRules.levelFactor(lv + 1).toStringAsFixed(2)}',
                  style: DsText.body()),
              Text('Costo: ${cost.text}',
                  style: DsText.detail(
                      affordable ? DsColors.textSecondary : DsColors.danger)),
              SizedBox(height: DsSpace.sm),
              Row(children: [
                if (!_confirm)
                  DsButton('MEJORAR',
                      kind: DsButtonKind.primary,
                      onPressed: widget.editable && affordable
                          ? () => setState(() => _confirm = true)
                          : null)
                else ...[
                  DsButton('CONFIRMAR MEJORA',
                      kind: DsButtonKind.primary,
                      onPressed: () {
                        widget.onUpgrade(o.id);
                        setState(() => _confirm = false);
                      }),
                  SizedBox(width: DsSpace.sm),
                  DsButton('CANCELAR',
                      onPressed: () => setState(() => _confirm = false)),
                ],
              ]),
            ] else
              Text('Nivel máximo.', style: DsText.detail()),
          ],
        ],
      ),
    );
  }
}
