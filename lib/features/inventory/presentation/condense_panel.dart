import 'package:material_ui/material_ui.dart';

import '../../../app/design/design.dart';
import '../../../app/design/ds_layout_host.dart';
import '../../../app/widgets/action_row_icon.dart';
import '../../../app/theme/retro_type.dart';
import '../../../core/layout/layout_doc.dart';
import '../../../game_engine/models/item.dart';
import '../../../game_engine/models/session_action.dart';
import '../../../game_engine/rules/craft_rules.dart';
import '../../../game_engine/models/life_skills.dart' show kLifeMaterialIds;
import '../../../game_engine/rules/life_craft_rules.dart';
import '../../world/presentation/panels/life_icon.dart';
import '../../world/presentation/panels/life_item_grid.dart';
import 'craft_bench.dart' show materialColor, materialIcon;
import 'craft_layout.dart';
import 'shop_sections.dart';

/// CONDENSAR: pestaña propia de la ARMERÍA (v0.20.25; materials_economy.md
/// § 4.3, ui_minimal.md § 4). Izquierda "Elegí material" (las fuentes con
/// lo que tienes), flecha, derecha "Se condensa en" (el resultado); abajo
/// la receta, cuántas veces alcanza, la cantidad (×1 / MÁX) y CONDENSAR.
/// Sin azar y sin vuelta atrás; el host valida los fondos
/// (`CraftOp.condense`).
class CondensePanel extends StatefulWidget {
  const CondensePanel(
      {super.key,
      required this.shop,
      this.layout,
      this.layoutHooks,
      this.initialPending});

  final ShopContext shop;

  /// Layout fijo (Editor → LAYOUT); `null` = el del catálogo
  /// (editor_layout.md § 6).
  final LayoutDoc? layout;
  final DsLayoutHooks? layoutHooks;

  /// Material que sale y cantidad al abrir (vista previa del Editor).
  final (CraftMaterial, int)? initialPending;

  @override
  State<CondensePanel> createState() => _CondensePanelState();
}

class _CondensePanelState extends State<CondensePanel> {
  late CraftMaterial _out =
      widget.initialPending?.$1 ?? CraftRules.condensable.first;

  /// Cantidad pedida; `null` = MÁX.
  late int? _n = widget.initialPending?.$2 ?? 1;

  ShopContext get shop => widget.shop;

  static String _short(CraftMaterial m) => m.label.split(' ').first;

  @override
  Widget build(BuildContext context) {
    final p = shop.profile;
    final (from, need, cr) = CraftRules.condenseRecipe(_out)!;
    final max = CraftRules.condenseMax(p, _out);
    final n = (_n ?? max).clamp(1, max < 1 ? 1 : max);
    final a = CraftAction(CraftOp.condense, _out.name, index: n);
    final why = shop.view.session.run != null
        ? 'Solo en el Mundo'
        : max < 1
            ? 'No alcanza'
            : shop.guards.craft(p, a);
    final slots = <String, DsSlotBuilder>{
      CondenseLayout.title: (_) => const DsSectionHeader('Condensar'),
      CondenseLayout.intro: (_) =>
          Text('Sin azar. No se puede deshacer.', style: DsText.detail()),
      CondenseLayout.recipes: (_) => _picker(context, max),
      CondenseLayout.summary: (_) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              KeyedSubtree(
                key: const ValueKey('condense-summary'),
                child: Text(
                    '${need * n} ${_short(from)} + ₵${cr * n} → '
                    '$n ${_short(_out)}',
                    style: DsText.body()),
              ),
              KeyedSubtree(
                key: ValueKey('condense-have-${_out.name}'),
                child: Text('Alcanza para $max', style: DsText.detail()),
              ),
            ],
          ),
      CondenseLayout.error: (_) => why == null
          ? null
          : KeyedSubtree(
              key: const ValueKey('condense-error'),
              child: Text(why, style: DsText.detail(DsColors.textDisabled))),
      CondenseLayout.go: (_) => DsButton('CONDENSAR',
          key: const ValueKey('condense-go'),
          kind: DsButtonKind.primary,
          tooltip: why,
          onPressed: why != null
              ? null
              : () {
                  if (shop.controller.craft(a)) setState(() => _n = 1);
                }),
    };
    return DsLayoutHost(
      spec: CondenseLayout.spec,
      doc: widget.layout,
      hooks: widget.layoutHooks,
      slots: slots,
      frame: (context, box, r) => SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            r.region('head'),
            SizedBox(height: DsSpace.sm),
            r.region('recipes'),
            SizedBox(height: DsSpace.md),
            KeyedSubtree(
                key: const ValueKey('condense-confirm'),
                child: r.region('confirm')),
            SizedBox(height: DsSpace.md),
            _life(),
          ],
        ),
      ),
    );
  }

  /// Materiales de oficio (v0.27.0, materials_economy.md § 4.4): fibra,
  /// cebo y tabla para contratar y mejorar ayudantes. Grilla como el
  /// inventario; el detalle tiene la receta y CONDENSAR ×1 / ×5 / MÁX.
  Widget _life() {
    final p = shop.profile;
    final inWorld = shop.view.session.run == null;
    LifeItemCellData cell(String id) {
      final d = kLifeMaterials[id]!;
      final max = LifeCraftRules.maxTimes(p, id);
      Widget go(String label, int n) {
        final a = CraftAction(CraftOp.condense, '${LifeCraftRules.prefix}$id',
            index: n);
        final why = !inWorld
            ? 'Solo en el Mundo'
            : max < n || n < 1
                ? 'No alcanza'
                : shop.guards.craft(p, a);
        return DsButton(label,
            key: ValueKey('condense-life-$id-$label'),
            size: DsButtonSize.compact,
            kind: DsButtonKind.primary,
            tooltip: why,
            onPressed: why == null ? () => shop.controller.craft(a) : null);
      }

      return LifeItemCellData(
        id: 'condense-life-$id',
        icon: LifeIcon('mat_$id', switch (id) {
          'cebo' => LifeIconKind.pescado,
          'fibra' => LifeIconKind.cosecha,
          _ => LifeIconKind.herramienta,
        }, size: LifeItemGrid.iconSize),
        border: DsColors.border,
        search: d.name,
        count: p.life.craft(id),
        detail: LifeItemDetail(
          name: d.name,
          nameColor: DsColors.textTitle,
          description: d.description,
          lines: [
            'Receta: ${LifeCraftRules.recipeText(id)}',
            'Tenés ${p.life.craft(id)} · alcanza para $max',
          ],
          actions: [go('×1', 1), go('×5', 5), go('MÁX', max)],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const DsSectionHeader('Oficios'),
        Text(
            'Cosechas y pescados (nunca legendarios; primero los de menos '
            'valor) se condensan en materiales para los ayudantes.',
            style: DsText.detail()),
        SizedBox(height: DsSpace.xs),
        SizedBox(
          height: 240,
          child: LifeItemGrid(
            key: const ValueKey('condense-life'),
            groups: [
              LifeItemGroup(null, [for (final id in kLifeMaterialIds) cell(id)])
            ],
            empty: '',
          ),
        ),
      ],
    );
  }

  /// Material (izquierda) → resultado (derecha) y la cantidad.
  Widget _picker(BuildContext context, int max) {
    final p = shop.profile;
    Widget icon(CraftMaterial m) =>
        actionRowIcon(context, materialIcon(m), materialColor(m));
    final left = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const DsSectionHeader('Elegí material'),
        for (final out in CraftRules.condensable)
          if (CraftRules.condenseRecipe(out) case (final src, final need, _))
            DsActionRow(
              key: ValueKey('condense-pick-${out.name}'),
              icon: icon(src),
              title: _short(src),
              description: '$need → 1 ${_short(out)}',
              extra: Text('x${p.material(src)}', style: DsText.body()),
              selected: out == _out,
              onTap: () => setState(() {
                _out = out;
                _n = 1;
              }),
            ),
      ],
    );
    final right = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const DsSectionHeader('Se condensa en'),
        DsListRow(
          key: const ValueKey('condense-result'),
          leading: icon(_out),
          title: _short(_out),
          titleColor: DsColors.textTitle,
          subtitle: _out.description,
          trailing: Text('x${p.material(_out)}', style: DsText.body()),
        ),
      ],
    );
    Widget amount(String label, int? n, String key) => DsButton(label,
        key: ValueKey('condense-${_out.name}-$key'),
        size: DsButtonSize.compact,
        selected: _n == n,
        onPressed: max < 1 ? null : () => setState(() => _n = n));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(builder: (context, box) {
          final arrow = Padding(
            padding: EdgeInsets.all(DsSpace.sm),
            child: Text('→', style: RetroType.style(RetroType.title, color: DsColors.textSecondary)),
          );
          // Angosto (o texto ENORME): una debajo de la otra.
          if (box.maxWidth < RetroType.width(context, 640)) {
            return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  left,
                  Center(
                      child: Text('↓',
                          style: RetroType.style(RetroType.title,
                              color: DsColors.textSecondary))),
                  right
                ]);
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [Expanded(child: left), arrow, Expanded(child: right)],
          );
        }),
        SizedBox(height: DsSpace.sm),
        Wrap(
          spacing: DsSpace.sm,
          runSpacing: DsSpace.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text('CANTIDAD', style: DsText.subtitle()),
            amount('×1', 1, '1'),
            amount('MÁX ($max)', null, 'all'),
          ],
        ),
      ],
    );
  }
}
