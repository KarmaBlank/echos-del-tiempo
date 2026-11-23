import 'package:material_ui/material_ui.dart';

import '../../theme/retro_text.dart';
import '../ds_button.dart';
import '../ds_components.dart';
import '../ds_dialogue.dart';
import '../ds_tokens.dart';
import 'ds_registry.dart';

/// Tonos de texto (sin colores libres: todos son roles del tema).
const _tones = [
  DsVariant('normal', 'Normal'),
  DsVariant('secundario', 'Secundario'),
  DsVariant('peligro', 'Peligro'),
  DsVariant('exito', 'Éxito'),
  DsVariant('recompensa', 'Recompensa'),
];

Color _toneColor(String? tone, DsTextStyleId style) => switch (tone) {
      'secundario' => DsColors.textSecondary,
      'peligro' => DsColors.danger,
      'exito' => DsColors.success,
      'recompensa' => DsColors.reward,
      _ => style.color,
    };

const _surfaces = [
  DsVariant('superficie', 'Superficie'),
  DsVariant('elevada', 'Elevada'),
  DsVariant('hundida', 'Hundida'),
];

Color _surfaceColor(String? v) => switch (v) {
      'elevada' => DsColors.surfaceRaised,
      'hundida' => DsColors.surfaceSunken,
      _ => DsColors.surface,
    };

Alignment _alignOf(TextAlign a) => switch (a) {
      TextAlign.center => Alignment.center,
      TextAlign.end || TextAlign.right => Alignment.centerRight,
      _ => Alignment.centerLeft,
    };

/// Los componentes del sistema de diseño que ofrece la paleta del editor
/// de pantallas (docs/specs/screen_editor.md § 1). Para sumar uno nuevo:
/// agregarlo acá (o `DsRegistry.instance.register`).
final dsDefaultComponents = <DsComponentSpec>[
  // ── Átomos ──
  DsComponentSpec(
    id: 'text',
    name: 'Texto',
    level: DsLevel.atom,
    variants: _tones,
    textStyles: DsTextStyleId.values,
    props: const {
      DsProp.text,
      DsProp.variant,
      DsProp.textStyle,
      DsProp.role,
      DsProp.align
    },
    defaultText: 'Texto',
    defaultSize: const Size(240, 32),
    textColor: _toneColor,
    build: (context, e) {
      final st = e.textStyle ?? DsTextStyleId.body;
      return _FitDown(
        alignment: _alignOf(e.align),
        wrap: true,
        child: Align(
          alignment: _alignOf(e.align),
          widthFactor: 1,
          heightFactor: 1,
          child: Text(retroText(e.text),
              textAlign: e.align,
              style: st.style(_toneColor(e.variant, st))),
        ),
      );
    },
  ),
  DsComponentSpec(
    id: 'button',
    name: 'Botón',
    level: DsLevel.atom,
    interactive: true,
    variants: const [
      DsVariant('secundario', 'Secundario'),
      DsVariant('primario', 'Principal'),
      DsVariant('fantasma', 'Fantasma'),
      DsVariant('peligro', 'Peligro'),
    ],
    sizes: const [
      DsVariant('normal', 'Normal'),
      DsVariant('compacto', 'Compacto'),
    ],
    textStyles: const [DsTextStyleId.subtitle],
    props: const {DsProp.text, DsProp.variant, DsProp.size, DsProp.action},
    defaultText: 'BOTÓN',
    defaultSize: const Size(200, 40),
    textPadding: const EdgeInsets.symmetric(horizontal: 19, vertical: 11),
    surface: (v) => v == 'fantasma' ? null : DsColors.surfaceRaised,
    textColor: (v, _) => switch (v) {
      'primario' => DsColors.actionPrimary,
      'peligro' => DsColors.danger,
      _ => DsColors.textPrimary,
    },
    // La marca (NUEVO) va en la esquina, encima del botón: no suma ancho,
    // así el texto no se achica para hacerle lugar.
    build: (context, e) {
      final button = _FitDown(
        child: DsButton(
          e.text,
          kind: switch (e.variant) {
            'primario' => DsButtonKind.primary,
            'fantasma' => DsButtonKind.ghost,
            _ => DsButtonKind.secondary,
          },
          size: e.size == 'compacto'
              ? DsButtonSize.compact
              : DsButtonSize.normal,
          accent: e.variant == 'peligro' ? DsColors.danger : null,
          tooltip: e.tooltip,
          onPressed: e.onPressed,
        ),
      );
      if (e.badge == null) return button;
      return Stack(
        clipBehavior: Clip.none,
        children: [
          button,
          Positioned(
            top: -DsSpace.sm,
            right: -DsSpace.sm,
            child: IgnorePointer(child: DsBadge(e.badge!)),
          ),
        ],
      );
    },
  ),
  DsComponentSpec(
    id: 'icon_button',
    name: 'Botón de ícono',
    level: DsLevel.atom,
    interactive: true,
    props: const {DsProp.text, DsProp.action},
    textStyles: const [DsTextStyleId.subtitle],
    defaultText: '?',
    defaultSize: const Size(40, 40),
    textPadding: const EdgeInsets.all(11),
    surface: (_) => DsColors.surfaceRaised,
    textColor: (_, __) => DsColors.textPrimary,
    build: (context, e) => _FitDown(
      child: DsButton.icon(Text(retroText(e.text)),
          tooltip: e.tooltip ?? e.text, onPressed: e.onPressed),
    ),
  ),
  DsComponentSpec(
    id: 'badge',
    name: 'Insignia',
    level: DsLevel.atom,
    variants: const [
      DsVariant('llena', 'Llena'),
      DsVariant('neutra', 'Neutra'),
    ],
    props: const {DsProp.text, DsProp.variant},
    defaultText: 'NUEVO',
    defaultSize: const Size(80, 24),
    build: (context, e) => Align(
        alignment: Alignment.centerLeft,
        child: DsBadge(e.text, neutral: e.variant == 'neutra')),
  ),
  DsComponentSpec(
    id: 'meter',
    name: 'Medidor',
    level: DsLevel.atom,
    variants: const [
      DsVariant('vida', 'Vida'),
      DsVariant('mana', 'Maná'),
      DsVariant('recompensa', 'Recompensa'),
    ],
    props: const {DsProp.variant},
    defaultSize: const Size(200, 8),
    build: (context, e) => Align(
      alignment: Alignment.centerLeft,
      child: DsMeter(7, 10,
          color: switch (e.variant) {
            'mana' => DsColors.mp,
            'recompensa' => DsColors.reward,
            _ => DsColors.success,
          }),
    ),
  ),
  // ── Moléculas ──
  DsComponentSpec(
    id: 'section_header',
    name: 'Encabezado de sección',
    level: DsLevel.molecule,
    props: const {DsProp.text, DsProp.role},
    textStyles: const [DsTextStyleId.subtitle],
    defaultText: 'SECCIÓN',
    defaultSize: const Size(400, 40),
    textColor: (_, __) => DsColors.textSubtitle,
    build: (context, e) => DsSectionHeader(e.text),
  ),
  DsComponentSpec(
    id: 'search_field',
    name: 'Buscador',
    level: DsLevel.molecule,
    interactive: true,
    props: const {DsProp.text},
    defaultText: 'BUSCAR',
    defaultSize: const Size(240, 40),
    build: (context, e) => Align(
        alignment: Alignment.centerLeft,
        child: DsSearchField(hint: e.text, width: 240)),
  ),
  DsComponentSpec(
    id: 'card',
    name: 'Tarjeta',
    level: DsLevel.molecule,
    variants: const [
      DsVariant('normal', 'Normal'),
      DsVariant('elegida', 'Elegida'),
    ],
    props: const {DsProp.text, DsProp.variant},
    textStyles: const [DsTextStyleId.body],
    defaultText: 'Tarjeta',
    defaultSize: const Size(240, 80),
    textPadding: const EdgeInsets.all(16),
    surface: (_) => DsColors.surface,
    textColor: (_, __) => DsColors.textPrimary,
    build: (context, e) => SizedBox.expand(
      child: DsCard(
          selected: e.variant == 'elegida',
          child: Text(retroText(e.text), style: DsText.body())),
    ),
  ),
  // ── Organismos ──
  DsComponentSpec(
    id: 'data_grid',
    name: 'Grilla de ítems',
    level: DsLevel.organism,
    variants: const [
      DsVariant('normal', 'Normal'),
      DsVariant('compacta', 'Compacta'),
    ],
    props: const {DsProp.variant, DsProp.dataSource},
    defaultSize: const Size(480, 240),
    surface: (_) => DsColors.surfaceSunken,
    build: (context, e) => _DataGrid(e),
  ),
  DsComponentSpec(
    id: 'slot',
    name: 'Hueco de la pantalla',
    level: DsLevel.organism,
    props: const {DsProp.slot},
    defaultSize: const Size(480, 240),
    build: (context, e) =>
        e.slot ??
        Container(
          decoration: BoxDecoration(
              border: Border.all(color: DsColors.border, width: 2)),
          alignment: Alignment.center,
          padding: EdgeInsets.all(DsSpace.sm),
          child: Text(retroText(e.slotLabel ?? 'HUECO SIN ELEGIR'),
              textAlign: TextAlign.center, style: DsText.detail()),
        ),
  ),
  // ── Plantillas ──
  DsComponentSpec(
    id: 'panel',
    name: 'Panel',
    level: DsLevel.template,
    variants: _surfaces,
    props: const {DsProp.variant},
    defaultSize: const Size(640, 400),
    surface: _surfaceColor,
    build: (context, e) => Container(
      decoration: BoxDecoration(
        color: _surfaceColor(e.variant),
        border: Border.all(color: DsColors.border, width: 2),
      ),
    ),
  ),
  DsComponentSpec(
    id: 'titled_panel',
    name: 'Panel con título',
    level: DsLevel.template,
    variants: _surfaces,
    props: const {DsProp.text, DsProp.variant},
    textStyles: const [DsTextStyleId.subtitle],
    defaultText: 'PANEL',
    defaultSize: const Size(640, 400),
    textPadding: const EdgeInsets.all(16),
    surface: _surfaceColor,
    textColor: (_, __) => DsColors.textSubtitle,
    build: (context, e) => Container(
      decoration: BoxDecoration(
        color: _surfaceColor(e.variant),
        border: Border.all(color: DsColors.border, width: 2),
      ),
      padding: EdgeInsets.symmetric(horizontal: DsSpace.md),
      alignment: Alignment.topLeft,
      child: DsSectionHeader(e.text),
    ),
  ),
];

/// Grilla de ítems ligada a una fuente de datos (tipo INVENTARIO).
class _DataGrid extends StatelessWidget {
  const _DataGrid(this.e);
  final DsElementContext e;

  @override
  Widget build(BuildContext context) {
    final compact = e.variant == 'compacta';
    final cell = compact ? 96.0 : 144.0;
    return Container(
      color: DsColors.surfaceSunken,
      padding: EdgeInsets.all(DsSpace.sm),
      child: e.data.isEmpty
          ? Center(child: Text('SIN ÍTEMS', style: DsText.detail()))
          : SingleChildScrollView(
              child: Wrap(
                spacing: DsSpace.xs,
                runSpacing: DsSpace.xs,
                children: [
                  for (final d in e.data)
                    SizedBox(
                      width: cell,
                      height: compact ? 40 : 56,
                      child: DsCard(
                        padding: EdgeInsets.all(DsSpace.xs),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(retroText(d.label),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: DsText.body()),
                            if (!compact && d.detail.isNotEmpty)
                              Text(retroText(d.detail),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: DsText.detail()),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

/// Llena la caja del elemento y, si el contenido no entra (texto grande),
/// lo achica hasta que entre: nunca se corta ni se desborda
/// (screen_editor.md § 2.1). [wrap]: el ancho queda fijo (el texto baja
/// de renglón) y solo se achica si se pasa de alto.
class _FitDown extends StatelessWidget {
  const _FitDown(
      {required this.child,
      this.alignment = Alignment.center,
      this.wrap = false});

  final Widget child;
  final Alignment alignment;
  final bool wrap;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, box) {
          if (!box.hasBoundedWidth || !box.hasBoundedHeight) return child;
          return FittedBox(
            fit: BoxFit.scaleDown,
            alignment: alignment,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minWidth: box.maxWidth,
                maxWidth: wrap ? box.maxWidth : double.infinity,
                minHeight: box.maxHeight,
              ),
              child: child,
            ),
          );
        },
      );
}
