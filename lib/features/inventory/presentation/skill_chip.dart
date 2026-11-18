import 'package:material_ui/material_ui.dart';

import '../../../app/theme/panel_frame.dart';
import '../../../app/theme/proto_colors.dart';
import '../../../app/theme/proto_markup.dart';
import '../../../app/theme/retro_text.dart';
import '../../../app/theme/retro_theme.dart';
import '../../../app/widgets/menu_focus.dart';
import '../../../game_engine/data/branch_ults_catalog.dart' show itemUlt;
import '../../../game_engine/models/item.dart';
import '../../../game_engine/models/player_state.dart';
import '../../../game_engine/models/skill.dart';
import '../../../game_engine/rules/progression_rules.dart';
import '../domain/skill_tip.dart';

/// Nombre de una habilidad (o ULT) con su ficha: mouse encima o foco de
/// teclado = tooltip con lo mismo que dice la batalla (tipo, MP, daño con
/// tus stats, objetivos, estados, escudos...). Ver
/// docs/specs/panels.md § "Ficha de habilidad (v0.5.1)".
class SkillChip extends StatelessWidget {
  const SkillChip({
    super.key,
    required this.skill,
    this.stats,
    this.ultimate = false,
    this.note,
    this.color,
    this.suffix,
  });

  final SkillDef skill;

  /// Los stats de quien mira (números calculados).
  final DerivedStats? stats;
  final bool ultimate;

  /// Línea extra en la ficha (markup), p. ej. `(trasladada)`.
  final String? note;

  /// Color del nombre (por defecto tinta; ULT en rosa).
  final Color? color;

  /// Markup chico después del nombre (`(nueva) ▲`).
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    final c = color ?? (ultimate ? ProtoColors.pink : ProtoColors.ink);
    return RetroTooltip(
      message:
          skillTipMarkup(skill, stats: stats, ultimate: ultimate, note: note),
      // Enfocable (Tab / flechas: la ficha aparece con el foco) pero sin
      // tomar el clic: el clic sigue a la tarjeta o fila de abajo.
      child: _ChipFocus(
        key: ValueKey('skill-chip-${skill.id}'),
        builder: (hot) => Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
          decoration: BoxDecoration(
            color: hot
                ? ProtoColors.button
                : ProtoColors.bg.withValues(alpha: 0.5),
            border: Border.all(
                color: hot ? ProtoColors.sky : ProtoColors.panelBorder,
                width: RetroTheme.thinBorderWidth),
          ),
          child: ProtoText(
              '${ultimate ? 'ULT ' : ''}${protoEsc(skill.name)}'
              '${suffix == null ? '' : ' $suffix'} '
              '${protoColor(ProtoColors.sky, '?')}',
              style: TextStyle(color: c)),
        ),
      ),
    );
  }
}

/// Las habilidades de un arma (base, trasladadas en naranja) y su ULT,
/// cada una un [SkillChip].
class SkillChips extends StatelessWidget {
  const SkillChips({
    super.key,
    required this.rules,
    required this.item,
    this.stats,
    this.label = 'Habilidades',
    this.isNew,
  });

  final ProgressionRules rules;
  final ItemInstance item;
  final DerivedStats? stats;
  final String? label;

  /// Marca en verde las que devuelvan `true` (la recién traída).
  final bool Function(String id)? isNew;

  @override
  Widget build(BuildContext context) {
    final cat = rules.catalog;
    final w = cat.weapons[item.baseId];
    final ult = itemUlt(item) ?? (w == null ? null : cat.ultimates[w.type]);
    // Una sección: Tab salta todas las habilidades de una vez.
    return NavSection(
        child: Wrap(
      key: const ValueKey('skill-chips'),
      spacing: 6,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (label != null)
          Text(retroText(label!),
              style: const TextStyle(color: ProtoColors.sky)),
        for (final id in rules.items.skillsOf(item))
          if (cat.skills[id] case final s?)
            SkillChip(
              skill: s,
              stats: stats,
              color: (isNew?.call(id) ?? false)
                  ? ProtoColors.green
                  : (w?.skillIds.contains(id) ?? false)
                      ? null
                      : ProtoColors.orange,
              suffix: (isNew?.call(id) ?? false) ? '(nueva)' : null,
              note: (w?.skillIds.contains(id) ?? false)
                  ? null
                  : protoColor(ProtoColors.orange, 'Trasladada de otra arma'),
            ),
        if (ult != null) SkillChip(skill: ult, stats: stats, ultimate: true),
      ],
    ));
  }
}

class _ChipFocus extends StatefulWidget {
  const _ChipFocus({super.key, required this.builder});

  final Widget Function(bool hot) builder;

  @override
  State<_ChipFocus> createState() => _ChipFocusState();
}

class _ChipFocusState extends State<_ChipFocus> {
  bool _hover = false, _focus = false;

  @override
  Widget build(BuildContext context) => Focus(
        onFocusChange: (f) => setState(() => _focus = f && keyboardHighlight),
        child: MouseRegion(
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: FocusRing(
            focused: _focus,
            pointer: false,
            child: widget.builder(_hover || _focus),
          ),
        ),
      );
}
