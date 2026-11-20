import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../app/design/design.dart';
import '../../../app/theme/proto_colors.dart';
import '../../../app/theme/proto_markup.dart';
import '../../../app/theme/retro_text.dart';
import '../../../app/theme/retro_theme.dart';
import '../domain/skill_text.dart' show SkillReach;

/// Ventana de comandos de la batalla (docs/specs/battle_presentation.md
/// § "Barra de batalla", con el sistema de diseño desde v0.12:
/// design_system.md § 10.3): tres columnas — categorías, acciones de la
/// categoría (filas `DsListRow` de una línea: nombre, etiquetas y costo a
/// la derecha) y el detalle de la elegida (quién actúa arriba, motivos en
/// rojo, resumen de una línea y el resto en un `DsFold`). No tiene estado
/// propio: lo que está elegido lo decide `BattleViewState` (así las
/// teclas y el mouse andan igual).

/// Categorías del menú.
enum BattleCategory {
  attack('ATACAR'),
  skills('HABILIDADES'),
  duos('DÚOS'),
  ultimate('ULTIMATE'),
  items('OBJETOS'),
  defend('DEFENDER'),

  /// Pasar turno (v0.8.3): siempre la última.
  pass('PASAR');

  const BattleCategory(this.label);
  final String label;
}

/// Una acción del menú. [id] es estable (el id de la técnica, del dúo,
/// `attack`, `potion`...): las filas se arman con `ValueKey(id)`, así el
/// elemento nunca se reutiliza para otra acción.
class BattleAction {
  const BattleAction({
    required this.id,
    required this.name,
    required this.onSelect,
    this.value,
    this.cost,
    this.description = '',
    this.dual = false,
    this.reason,
    this.separatorBefore,
    this.instant = false,
    this.reach,
    this.mpCost,
    this.pulseCost,
    this.summary,
  });

  final String id;

  /// Nombre (markup corto; en la fila va como texto plano).
  final String name;

  /// La cifra principal (daño estimado, cura...), markup corto. En la
  /// fila va como dato corto en Detalle (sin [summary]).
  final String? value;

  /// Costo a la derecha (`x2`, `100%`), markup corto. Las habilidades
  /// usan [mpCost] / [pulseCost] (`DsCost`).
  final String? cost;

  /// Detalle de la columna de descripción (markup). Con [summary], todo
  /// va plegado; sin él, las dos primeras líneas se ven y el resto se
  /// pliega.
  final String description;

  /// ULT y dúos: nombre en naranja.
  final bool dual;

  /// `null` = deshabilitada.
  final VoidCallback? onSelect;

  /// Por qué está deshabilitada (en rojo arriba del detalle).
  final String? reason;

  /// Línea fina arriba de la fila (p. ej. el separador de las Instante).
  /// No es una acción: los atajos 1-9 no cambian.
  final String? separatorBefore;

  /// Etiqueta INSTANTE (celeste).
  final bool instant;

  /// Etiqueta de alcance (`1 ENEMIGO`, `TODOS`...).
  final SkillReach? reach;

  /// Costos de habilidad (MP azul, Pulso dorado; rojo si no alcanza).
  final int? mpCost;
  final int? pulseCost;

  /// Resumen de una línea arriba del detalle (markup).
  final String? summary;
}

/// Una categoría con sus acciones (vacía = no se muestra).
class BattleCategoryEntry {
  const BattleCategoryEntry(this.category, this.actions, {this.badge});
  final BattleCategory category;
  final List<BattleAction> actions;

  /// Markup a la derecha del nombre (`45%`, `x3`).
  final String? badge;
}

/// La ventana. [visible] son las acciones de la página que se ve (las
/// teclas 1-9 las eligen en ese orden).
class BattleCommandWindow extends StatelessWidget {
  const BattleCommandWindow({
    super.key,
    required this.actorName,
    required this.categories,
    required this.category,
    required this.visible,
    required this.selected,
    required this.onCategory,
    required this.onHoverAction,
    required this.target,
    required this.resources,
    this.header,
    this.extra,
    this.mp,
    this.pulse,
    this.hints =
        'Enter: confirmar · Esc: volver · Flechas: elegir · Q/Tab: objetivo'
            ' · P: pasar',
  });

  final String actorName;
  final List<BattleCategoryEntry> categories;
  final BattleCategory category;
  final List<BattleAction> visible;

  /// Índice de la acción elegida en [visible].
  final int selected;
  final ValueChanged<BattleCategory> onCategory;
  final ValueChanged<int> onHoverAction;

  /// `Objetivo: Limo 71/71 HP · Quiebre 0/59` (markup).
  final String target;

  /// `MP 11/11 · ULT 45%` (markup), arriba a la derecha.
  final String resources;

  /// Línea de arriba de las acciones (p. ej. "¿A quién le das...?").
  final String? header;

  /// Debajo del objetivo (p. ej. las mecánicas del jefe).
  final Widget? extra;

  /// MP y Pulso de quien actúa: el costo que no alcanza va en rojo.
  final num? mp;
  final int? pulse;
  final String hints;

  @override
  Widget build(BuildContext context) {
    final sel =
        selected >= 0 && selected < visible.length ? visible[selected] : null;
    final catW = RetroType.width(context, 170);
    // En pantallas anchas la ventana no se estira: tope de ancho,
    // centrada.
    return LayoutBuilder(builder: (context, box) {
      final w = math.min(box.maxWidth, RetroType.width(context, maxWidth));
      return Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: w,
          height: box.maxHeight,
          child: _window(context, catW, sel),
        ),
      );
    });
  }

  /// Tope de ancho de la ventana a texto Normal (px lógicos).
  static const maxWidth = 1240.0;

  Widget _window(BuildContext context, double catW, BattleAction? sel) {
    // Las filas no toman el foco: las teclas las maneja la batalla
    // (Enter confirma la acción elegida, no la última fila clickeada).
    return ExcludeFocus(
      child: Container(
        key: const ValueKey('battle-menu'),
        padding: EdgeInsets.all(DsSpace.xs),
        decoration: BoxDecoration(
          color: DsColors.surface,
          border: Border.all(color: DsColors.selected, width: 2),
        ),
        child: DefaultTextStyle.merge(
          style: DsText.body(),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: catW,
                child: _Categories(
                  categories: categories,
                  category: category,
                  onCategory: onCategory,
                ),
              ),
              SizedBox(width: DsSpace.xs),
              Expanded(
                flex: 5,
                child: _Actions(
                  header: header,
                  visible: visible,
                  selected: selected,
                  onHover: onHoverAction,
                  mp: mp,
                  pulse: pulse,
                ),
              ),
              SizedBox(width: DsSpace.xs),
              Expanded(
                flex: 4,
                child: _Description(
                  actorName: actorName,
                  action: sel,
                  target: target,
                  resources: resources,
                  hints: hints,
                  extra: extra,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Categories extends StatelessWidget {
  const _Categories({
    required this.categories,
    required this.category,
    required this.onCategory,
  });

  final List<BattleCategoryEntry> categories;
  final BattleCategory category;
  final ValueChanged<BattleCategory> onCategory;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final c in categories)
            DsListRow(
              key: ValueKey('battle-cat-${c.category.name}'),
              title: retroText(c.category.label),
              selected: c.category == category,
              enabled: c.actions.any((a) => a.onSelect != null),
              onTap: () => onCategory(c.category),
              compact: true,
              trailing: c.badge == null
                  ? null
                  : ProtoText(c.badge!, maxLines: 1, style: DsText.detail()),
            ),
        ],
      ),
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({
    required this.header,
    required this.visible,
    required this.selected,
    required this.onHover,
    this.mp,
    this.pulse,
  });

  final String? header;
  final List<BattleAction> visible;
  final int selected;
  final ValueChanged<int> onHover;
  final num? mp;
  final int? pulse;

  Widget? _trailing(BattleAction a, double width) {
    final parts = <Widget>[
      if (a.instant) const DsTag.instant(),
      if (a.reach case final r?)
        DsTag(r.label.toUpperCase(),
            color: ProtoColors.parse(r.hex) ?? DsColors.textSecondary),
      if (a.mpCost case final c?)
        DsCost.mp(c, affordable: mp == null || mp! >= c),
      if (a.pulseCost case final c?)
        DsCost.pulse(c, affordable: pulse == null || pulse! >= c),
      if (a.cost case final c? when a.mpCost == null && a.pulseCost == null)
        ProtoText(c, maxLines: 1),
    ];
    if (parts.isEmpty) return null;
    // Con texto ENORME las etiquetas se achican antes que desbordar: tope
    // de 55 % del ancho de la fila.
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: width * 0.55),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerRight,
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          for (final (i, p) in parts.indexed) ...[
            if (i > 0) SizedBox(width: DsSpace.sm),
            p,
          ],
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
        builder: (context, box) => _list(context, box.maxWidth));
  }

  Widget _list(BuildContext context, double width) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (header != null)
            Padding(
              padding: EdgeInsets.only(bottom: DsSpace.xs),
              child: ProtoText(header!,
                  key: const ValueKey('battle-header'), style: DsText.body()),
            ),
          for (final (i, a) in visible.indexed) ...[
            if (a.separatorBefore case final s?)
              Container(
                key: ValueKey('battle-sep-${a.id}'),
                margin: EdgeInsets.only(bottom: DsSpace.xs),
                padding: const EdgeInsets.only(bottom: 2),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: DsColors.border)),
                ),
                child:
                    Text(retroText(s), style: DsText.detail(DsColors.instant)),
              ),
            // Clave estable por acción: nunca se reutiliza la fila de
            // otra técnica al cambiar de turno, de página o de categoría.
            MouseRegion(
              key: ValueKey('battle-act-${a.id}'),
              onEnter: (_) => onHover(i),
              child: DsListRow(
                leading: SizedBox(
                  width: RetroType.em(context, 1.5),
                  child: Text(i < 9 ? '${i + 1}' : '', style: DsText.detail()),
                ),
                title: retroText(protoPlain(a.name)),
                detail: a.summary == null && a.value != null
                    ? retroText(protoPlain(a.value!))
                    : null,
                titleColor: a.dual ? DsColors.warning : null,
                selected: i == selected,
                enabled: a.onSelect != null,
                onTap: a.onSelect,
                compact: true,
                trailing: _trailing(a, width),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Description extends StatelessWidget {
  const _Description({
    required this.actorName,
    required this.action,
    required this.target,
    required this.resources,
    required this.hints,
    this.extra,
  });

  final String actorName;
  final Widget? extra;
  final BattleAction? action;
  final String target;
  final String resources;
  final String hints;

  /// Resumen visible y lo plegado de [a].
  static (String, String) _split(BattleAction a) {
    if (a.summary case final s?) return (s, a.description);
    final lines = a.description.split('<br>');
    return (lines.take(2).join('<br>'), lines.skip(2).join('<br>'));
  }

  @override
  Widget build(BuildContext context) {
    final a = action;
    final parts = a == null ? null : _split(a);
    return Container(
      key: const ValueKey('battle-desc'),
      padding: EdgeInsets.all(DsSpace.sm),
      color: DsColors.surfaceSunken,
      // Todo scrollea (también los recursos: con texto ENORME ocupan
      // varias líneas).
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Quién actúa (izquierda) y sus recursos (derecha).
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(retroText(actorName),
                      key: const ValueKey('battle-actor'),
                      style: DsText.subtitle(DsColors.textTitle)),
                ),
                SizedBox(width: DsSpace.sm),
                // Con texto ENORME baja de línea en vez de desbordar.
                Flexible(
                  child: ProtoText(resources,
                      key: const ValueKey('battle-resources'),
                      style: DsText.detail(),
                      textAlign: TextAlign.right),
                ),
              ],
            ),
            SizedBox(height: DsSpace.xs),
            // Lo que falta, arriba y en rojo: una línea por condición.
            if (a?.reason case final r?)
              for (final (i, l) in r.split('\n').indexed)
                Text(retroText(l),
                    key: ValueKey('battle-reason-$i'),
                    style: DsText.body(DsColors.danger)),
            if (a != null)
              Column(
                key: ValueKey('battle-desc-${a.id}'),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ProtoText(parts!.$1, style: DsText.body()),
                  if (parts.$2.isNotEmpty)
                    DsFold(
                      key: ValueKey('battle-fold-${a.id}'),
                      child: ProtoText(parts.$2, style: DsText.detail()),
                    ),
                ],
              ),
            if (target.isNotEmpty) ...[
              SizedBox(height: DsSpace.xs),
              ProtoText(target,
                  key: const ValueKey('battle-target'), style: DsText.detail()),
            ],
            if (extra != null) ...[SizedBox(height: DsSpace.xs), extra!],
            // Las teclas al final: nunca le quitan lugar al detalle.
            SizedBox(height: DsSpace.xs),
            Text(retroText(hints), style: DsText.detail()),
          ],
        ),
      ),
    );
  }
}

/// `<span style="color:hex">texto</span>` con el texto escapado.
String hexSpanSafe(String hex, String text) =>
    '<span style="color:$hex">${protoEsc(text)}</span>';
