import 'package:material_ui/material_ui.dart';

import '../../core/layout/layout_catalog.dart';
import '../../core/layout/layout_doc.dart';
import '../../core/layout/layout_spec.dart';
import '../theme/retro_type.dart';
import 'ds_tokens.dart';

/// Arma el widget de un slot; `null` = no se muestra ahora (p. ej. la
/// nota de la pestaña ECOS en otra pestaña).
typedef DsSlotBuilder = Widget? Function(BuildContext context);

/// El template de la pantalla: recibe el ancho disponible y las
/// regiones ya armadas por datos, y las compone (lado a lado, apiladas,
/// con su lógica de escala). Las regiones son del código (§ 2.1).
typedef DsLayoutFrame = Widget Function(
    BuildContext context, BoxConstraints box, DsRegions regions);

/// Ganchos del Editor → LAYOUT (selección, arrastre, medición). En el
/// juego son `null`: el host no agrega nada.
abstract class DsLayoutHooks {
  /// Envuelve cada slot (también los grupos). [container] es su región o
  /// grupo e [index] su posición ahí.
  Widget slot(BuildContext context, String id, String container, int index,
      Widget child);

  /// Envuelve cada región y el interior de cada grupo (destinos).
  Widget container(BuildContext context, String id, LayoutAxis axis,
      List<String> children, Widget child);

  /// Se reporta el corte elegido en cada build.
  void breakpoint(LayoutBreakpoint bp) {}
}

/// Las regiones resueltas para el corte actual.
class DsRegions {
  DsRegions._(this._host, this._context, this.breakpoint, this.layout);
  final DsLayoutHost _host;
  final BuildContext _context;
  final LayoutBreakpoint breakpoint;
  final ResolvedLayout layout;

  /// ¿La región no tiene nada? (en el Editor nunca: se ve como destino).
  bool isEmpty(String region) =>
      _host.hooks == null &&
      layout.of(region).every((id) => !_host._visible(_context, id, layout));

  /// La región armada (columna, fila o wrap según su spec).
  Widget region(String id) {
    final spec = _host.spec.region(id);
    return _host._container(
        _context, id, spec?.axis ?? LayoutAxis.column, layout, spec?.align);
  }
}

/// Template genérico (§ 2.7): recibe el catálogo de slots de la pantalla
/// y el [LayoutDoc] resuelto; dentro de un `LayoutBuilder` elige el corte
/// y arma `Row`/`Column`/`Wrap`. Sin lógica de juego ni redondeos.
///
/// Rendimiento: el doc es inmutable y su resolución por corte está
/// cacheada; por build solo se mide el ancho y se elige el corte. Solo
/// escucha al [LayoutCatalog] (recarga en caliente), nunca por frame.
class DsLayoutHost extends StatelessWidget {
  const DsLayoutHost({
    super.key,
    required this.spec,
    required this.slots,
    required this.frame,
    this.doc,
    this.catalog,
    this.hooks,
  });

  final LayoutScreenSpec spec;
  final Map<String, DsSlotBuilder> slots;
  final DsLayoutFrame frame;

  /// Doc fijo (Editor); si es `null`, el del [catalog].
  final LayoutDoc? doc;
  final LayoutCatalog? catalog;
  final DsLayoutHooks? hooks;

  /// El corte para un ancho [w] con el tamaño de texto de [context].
  static LayoutBreakpoint breakpointOf(BuildContext context, double w) =>
      LayoutBreakpoints.of(
          w / RetroType.width(context, LayoutBreakpoints.txBase));

  @override
  Widget build(BuildContext context) {
    final d = doc;
    if (d != null) return _layout(d);
    final c = catalog ?? LayoutCatalog.instance;
    return ListenableBuilder(
        listenable: c, builder: (context, _) => _layout(c.docFor(spec)));
  }

  Widget _layout(LayoutDoc d) => LayoutBuilder(builder: (context, box) {
        final bp = breakpointOf(context, box.maxWidth);
        hooks?.breakpoint(bp);
        return frame(context, box, DsRegions._(this, context, bp, d.resolve(bp)));
      });

  Widget? _build(BuildContext context, String id) => slots[id]?.call(context);

  /// ¿Se ve algo de [id]? (un grupo, si se ve alguno de sus hijos).
  bool _visible(BuildContext context, String id, ResolvedLayout l) =>
      (spec.slots[id]?.group ?? false)
          ? l.of(id).any((c) => _visible(context, c, l))
          : _build(context, id) != null;

  static double _gap(String name) => switch (name) {
        'xs' => DsSpace.xs,
        'md' => DsSpace.md,
        'lg' => DsSpace.lg,
        'xl' => DsSpace.xl,
        'none' => 0,
        _ => double.tryParse(name) ?? DsSpace.sm,
      };

  Widget? _slot(BuildContext context, String id, String container, int index,
      ResolvedLayout l) {
    final s = spec.slots[id];
    final rule = l.ruleOf(id);
    Widget? w;
    if (s != null && s.group) {
      // En el juego, un grupo sin nada visible no ocupa lugar.
      if (hooks == null &&
          l.of(id).every((c) => _build(context, c) == null)) {
        return null;
      }
      w = _container(context, id, rule.axis ?? s.groupAxis, l, rule.align);
    } else {
      w = _build(context, id);
    }
    if (w == null) return null;
    if (rule.minWidth case final m?) {
      w = ConstrainedBox(
          constraints:
              BoxConstraints(minWidth: RetroType.width(context, m * LayoutBreakpoints.txBase)),
          child: w);
    }
    final h = hooks;
    return h == null ? w : h.slot(context, id, container, index, w);
  }

  Widget _container(BuildContext context, String id, LayoutAxis axis,
      ResolvedLayout l, LayoutAlign? align) {
    final ids = l.of(id);
    final kids = <(String, Widget)>[];
    for (var i = 0; i < ids.length; i++) {
      final w = _slot(context, ids[i], id, i, l);
      if (w != null) kids.add((ids[i], w));
    }
    final isGroup = spec.slots[id]?.group ?? false;
    final groupGap = _gap(spec.slots[id]?.groupGap ?? 'sm');
    final regionGap = _gap(spec.region(id)?.spacing ?? 'md');
    Widget out;
    switch (axis) {
      case LayoutAxis.wrap:
        out = Wrap(
          spacing: isGroup ? groupGap : regionGap,
          runSpacing: isGroup
              ? _gap(spec.slots[id]?.groupRunSpacing ?? 'xs')
              : _gap(spec.region(id)?.runSpacing ?? 'xs'),
          alignment: switch (align) {
            LayoutAlign.center => WrapAlignment.center,
            LayoutAlign.end => WrapAlignment.end,
            _ => WrapAlignment.start,
          },
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (var i = 0; i < kids.length; i++) ...[
              if (i > 0 && spec.slots[kids[i].$1]?.lead != null)
                SizedBox(width: _gap(spec.slots[kids[i].$1]!.lead!)),
              kids[i].$2,
            ],
          ],
        );
      case LayoutAxis.row:
        out = Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: isGroup
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < kids.length; i++) ...[
              if (i > 0)
                SizedBox(
                    width: isGroup ? groupGap : _gap(spec.slots[kids[i].$1]?.gap ?? 'sm')),
              _stretchRow(kids[i], l),
            ],
          ],
        );
      case LayoutAxis.column:
        out = Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: switch (align) {
            LayoutAlign.center => CrossAxisAlignment.center,
            LayoutAlign.end => CrossAxisAlignment.end,
            _ => CrossAxisAlignment.start,
          },
          children: [
            for (var i = 0; i < kids.length; i++) ...[
              if (i > 0)
                SizedBox(
                    height: isGroup ? DsSpace.xs : _gap(spec.slots[kids[i].$1]?.gap ?? 'sm')),
              _alignCol(kids[i], l),
            ],
          ],
        );
    }
    final h = hooks;
    return h == null ? out : h.container(context, id, axis, ids, out);
  }

  Widget _stretchRow((String, Widget) k, ResolvedLayout l) =>
      l.ruleOf(k.$1).stretch == true ? Flexible(child: k.$2) : k.$2;

  Widget _alignCol((String, Widget) k, ResolvedLayout l) {
    final r = l.ruleOf(k.$1);
    if (r.stretch == true) {
      return SizedBox(width: double.infinity, child: k.$2);
    }
    if (r.align == null) return k.$2;
    return Align(
        alignment: switch (r.align!) {
          LayoutAlign.center => Alignment.center,
          LayoutAlign.end => Alignment.centerRight,
          LayoutAlign.start => Alignment.centerLeft,
        },
        child: k.$2);
  }
}
