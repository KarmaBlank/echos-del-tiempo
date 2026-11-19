import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../app/theme/proto_colors.dart';
import '../../../app/theme/proto_markup.dart';
import '../../../app/theme/retro_text.dart';
import '../../../app/theme/retro_theme.dart';

/// Ventana de comandos de la batalla v0.5 (docs/specs/
/// battle_presentation.md § "Barra de batalla (v0.5)"): tres columnas
/// — categorías, acciones de la categoría (una línea cada una, costo a la
/// derecha) y la descripción de la acción elegida con quién actúa (arriba,
/// desde v0.8.3), el objetivo y las teclas. No tiene estado propio: lo que está elegido lo decide
/// `BattleViewState` (así las teclas y el mouse andan igual).

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
  });

  final String id;

  /// Nombre (markup corto).
  final String name;

  /// La cifra principal (daño estimado, cura...), markup corto.
  final String? value;

  /// Costo a la derecha (`4 MP`, `x2`, `100%`), markup corto.
  final String? cost;

  /// Detalle para la columna de descripción (markup).
  final String description;

  /// ULT y dúos: borde ámbar.
  final bool dual;

  /// `null` = deshabilitada.
  final VoidCallback? onSelect;

  /// Por qué está deshabilitada (se ve en la descripción).
  final String? reason;
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
    return Container(
      key: const ValueKey('battle-menu'),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: ProtoColors.panel,
        border: Border.all(color: ProtoColors.gold, width: 2),
      ),
      child: DefaultTextStyle.merge(
        style: RetroType.smallStyle.copyWith(color: ProtoColors.ink),
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
            const SizedBox(width: 6),
            Expanded(
              flex: 5,
              child: _Actions(
                header: header,
                visible: visible,
                selected: selected,
                onHover: onHoverAction,
              ),
            ),
            const SizedBox(width: 6),
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
          // Quién actúa va arriba de la descripción (v0.8.3): así las 7
          // categorías (con PASAR) entran sin scroll a texto Normal.
          for (final c in categories)
            _Row(
              key: ValueKey('battle-cat-${c.category.name}'),
              selected: c.category == category,
              enabled: c.actions.any((a) => a.onSelect != null),
              onTap: () => onCategory(c.category),
              child: Row(
                children: [
                  // Texto de lectura (como las filas de acciones): crece
                  // con el ajuste y no queda diminuto en pantallas anchas.
                  Expanded(
                    child: Text(retroText(c.category.label)),
                  ),
                  if (c.badge != null) ProtoText(c.badge!),
                ],
              ),
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
  });

  final String? header;
  final List<BattleAction> visible;
  final int selected;
  final ValueChanged<int> onHover;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (header != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: ProtoText(header!, key: const ValueKey('battle-header')),
            ),
          for (final (i, a) in visible.indexed)
            _Row(
              // Clave estable por acción: nunca se reutiliza la fila de
              // otra técnica al cambiar de turno, de página o de categoría.
              key: ValueKey('battle-act-${a.id}'),
              selected: i == selected,
              enabled: a.onSelect != null,
              dual: a.dual,
              onTap: a.onSelect,
              onHover: () => onHover(i),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: RetroType.em(context, 2),
                    child: Text(i < 9 ? '${i + 1}' : '',
                        style: RetroType.style(RetroType.label,
                            color: ProtoColors.sky)),
                  ),
                  // El nombre baja de línea antes que cortarse.
                  Expanded(
                    child: ProtoText(
                        '${a.name}${a.value == null ? '' : ' ${a.value}'}'),
                  ),
                  if (a.cost != null) ...[
                    const SizedBox(width: 8),
                    ProtoText(a.cost!),
                  ],
                ],
              ),
            ),
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

  @override
  Widget build(BuildContext context) {
    final a = action;
    return Container(
      key: const ValueKey('battle-desc'),
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: ProtoColors.bg,
        border: Border.all(color: ProtoColors.panelBorder, width: 2),
      ),
      // Todo scrollea (también los recursos: con texto ENORME ocupan
      // varias líneas).
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
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
                            style: RetroType.style(RetroType.label,
                                color: ProtoColors.title)),
                      ),
                      const SizedBox(width: 8),
                      // Con texto ENORME baja de línea en vez de desbordar.
                      Flexible(
                        child: ProtoText(resources,
                            key: const ValueKey('battle-resources'),
                            textAlign: TextAlign.right),
                      ),
                    ],
                  ),
                  if (a != null)
                    ProtoText(a.description,
                        key: ValueKey('battle-desc-${a.id}')),
                  if (a?.reason case final r?)
                    ProtoText(hexSpanSafe('#ff6b81', r)),
                  if (target.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    ProtoText(target, key: const ValueKey('battle-target')),
                  ],
                  if (extra != null) ...[const SizedBox(height: 4), extra!],
                  // Las teclas al final: nunca le quitan lugar al detalle.
                  const SizedBox(height: 4),
                  ProtoText(hints,
                      style: const TextStyle(color: ProtoColors.dim)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// `<span style="color:hex">texto</span>` con el texto escapado.
String hexSpanSafe(String hex, String text) =>
    '<span style="color:$hex">${protoEsc(text)}</span>';

/// Fila elegible: borde dorado si está elegida, más clara con el mouse;
/// 35 % de opacidad deshabilitada; ámbar en ULT y dúos.
class _Row extends StatefulWidget {
  const _Row({
    super.key,
    required this.child,
    required this.selected,
    required this.enabled,
    this.onTap,
    this.onHover,
    this.dual = false,
  });

  final Widget child;
  final bool selected;
  final bool enabled;
  final bool dual;
  final VoidCallback? onTap;
  final VoidCallback? onHover;

  @override
  State<_Row> createState() => _RowState();
}

class _RowState extends State<_Row> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final hot = _hover || widget.selected;
    final border = widget.selected
        ? ProtoColors.gold
        : widget.dual
            ? ProtoColors.amber
            : _hover
                ? ProtoColors.buttonHoverBorder
                : ProtoColors.panelBorder;
    // El clic toma también el hueco de abajo: la fila mide ≥ 24 px de
    // alto a texto Normal (accessibility.md § "Objetivos clicables").
    return MouseRegion(
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      onEnter: (_) {
        setState(() => _hover = true);
        widget.onHover?.call();
      },
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 3),
          child: Opacity(
            opacity: widget.enabled ? 1 : 0.45,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
              decoration: BoxDecoration(
                color: hot ? ProtoColors.buttonHover : ProtoColors.button,
                border: Border.all(color: border, width: 2),
              ),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}
