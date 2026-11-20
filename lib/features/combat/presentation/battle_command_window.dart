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
  /// ARMA (battle_attack_menu.md § 6): Atacar, Defender, filas
  /// contextuales (Liberar a X) y las Instante.
  weapon('ARMA'),
  skills('HABILIDADES'),
  duos('DÚOS'),
  ultimate('ULTIMATE'),
  items('OBJETOS'),

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
    this.disabledHint,
    this.separatorBefore,
    this.instant = false,
    this.reach,
    this.mpCost,
    this.pulseCost,
    this.ultCharge,
    this.count,
    this.summary,
  });

  final String id;

  /// Nombre (markup corto; en la fila va como texto plano).
  final String name;

  /// La cifra principal (daño estimado, cura...), markup corto. En la
  /// fila va como dato corto en Detalle (sin [summary]).
  final String? value;

  /// Costo a la derecha que no es MP / Pulso / ULT / cantidad (`½ turno`,
  /// `próximo ×½`, `45/90 HP`), markup corto, en Cuerpo como `DsCost`.
  /// Los costos de recurso usan [mpCost], [pulseCost], [ultCharge] y
  /// [count] (`DsCost`). Nunca un costo en [name].
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

  /// Motivo raro de la deshabilitada (condición de la habilidad, regla
  /// del tutorial...): tooltip al pasar el mouse por la fila gris. Los
  /// motivos básicos (MP visible, sin pociones, ULT sin cargar) no llevan.
  final String? disabledHint;

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

  /// Carga de ULT (%), `DsCost.ult`.
  final int? ultCharge;

  /// Cantidad que queda (pociones), `DsCost.count`.
  final int? count;

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

  /// Fila gris con motivo raro: tooltip del sistema (como `DsButton`).
  Widget _hinted(BattleAction a, Widget row) => a.onSelect == null &&
          a.disabledHint != null
      ? Tooltip(
          key: ValueKey('battle-hint-${a.id}'),
          message: retroText(a.disabledHint!),
          child: row)
      : row;

  Widget? _trailing(BattleAction a, double width) {
    final tags = <Widget>[
      if (a.instant) const DsTag.instant(),
      if (a.reach case final r?)
        DsTag(r.label.toUpperCase(),
            color: ProtoColors.parse(r.hex) ?? DsColors.textSecondary),
    ];
    final costs = <Widget>[
      if (a.mpCost case final c?)
        DsCost.mp(c, affordable: mp == null || mp! >= c),
      if (a.pulseCost case final c?)
        DsCost.pulse(c, affordable: pulse == null || pulse! >= c),
      if (a.ultCharge case final c?) DsCost.ult(c),
      if (a.count case final c?) DsCost.count(c),
      if (a.cost case final c?)
        ProtoText(c, maxLines: 1, style: DsText.body()),
    ];
    if (tags.isEmpty && costs.isEmpty) return null;
    Widget row(List<Widget> ws) =>
        Row(mainAxisSize: MainAxisSize.min, children: [
          for (final (i, p) in ws.indexed) ...[
            if (i > 0) SizedBox(width: DsSpace.sm),
            p,
          ],
        ]);
    // Tope de 55 % del ancho de la fila. Con texto ENORME se achican
    // primero las etiquetas; el costo va siempre al borde derecho y al
    // mismo tamaño en todas las categorías (solo se achica si él solo no
    // entra).
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: width * 0.55),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (tags.isNotEmpty)
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: row(tags),
            ),
          ),
        if (tags.isNotEmpty && costs.isNotEmpty) SizedBox(width: DsSpace.sm),
        if (costs.isNotEmpty)
          Flexible(
            child: FittedBox(
              key: const ValueKey('battle-cost'),
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerRight,
              child: row(costs),
            ),
          ),
      ]),
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
              child: _hinted(a, DsListRow(
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
              )),
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
            // Instante bajo el cursor: insignia del DS y qué significa.
            if (a != null && a.instant)
              Padding(
                key: const ValueKey('battle-instant-note'),
                padding: EdgeInsets.only(bottom: DsSpace.xs),
                child: Wrap(
                  spacing: DsSpace.xs,
                  runSpacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const DsTag.instant(),
                    Text(retroText('· no termina tu turno'),
                        style: DsText.body(DsColors.instant)),
                  ],
                ),
              ),
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
            // Sin sección OBJETIVO (v0.19.1): esa info vive en el tooltip
            // del enemigo (battle_presentation.md).
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
