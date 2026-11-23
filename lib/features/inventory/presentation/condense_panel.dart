import 'package:material_ui/material_ui.dart';

import '../../../app/design/design.dart';
import '../../../app/design/ds_layout_host.dart';
import '../../../app/widgets/action_row_icon.dart';
import '../../../app/theme/retro_type.dart';
import '../../../core/layout/layout_doc.dart';
import '../../../game_engine/models/item.dart';
import '../../../game_engine/models/session_action.dart';
import '../../../game_engine/rules/craft_rules.dart';
import 'craft_bench.dart' show materialColor, materialIcon;
import 'craft_layout.dart';
import 'inventory_strings.dart';
import 'shop_sections.dart';

/// CONDENSAR: pestaña propia de la ARMERÍA (v0.20.25; solo materiales de
/// arma desde v0.32.3: los de oficio están en el TALLER DE OFICIOS; materials_economy.md
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
    final s = invStrings(context);
    final why = shop.view.session.run != null
        ? s.t('ui.inventory.condense.world_only')
        : max < 1
            ? s.t('ui.inventory.condense.not_enough')
            : shop.guards.craft(p, a);
    final slots = <String, DsSlotBuilder>{
      CondenseLayout.title: (_) => DsSectionHeader(s.t('ui.inventory.condense.title')),
      CondenseLayout.intro: (_) =>
          Text(s.t('ui.inventory.condense.intro'), style: DsText.detail()),
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
                child: Text(s.t('ui.inventory.condense.enough_for', {'n': max}), style: DsText.detail()),
              ),
            ],
          ),
      CondenseLayout.error: (_) => why == null
          ? null
          : KeyedSubtree(
              key: const ValueKey('condense-error'),
              child: Text(why, style: DsText.detail(DsColors.textDisabled))),
      CondenseLayout.go: (_) => DsButton(s.t('ui.inventory.condense.go'),
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
          ],
        ),
      ),
    );
  }

  /// Material (izquierda) → resultado (derecha) y la cantidad.
  Widget _picker(BuildContext context, int max) {
    final p = shop.profile;
    final s = invStrings(context);
    Widget icon(CraftMaterial m) =>
        actionRowIcon(context, materialIcon(m), materialColor(m));
    final left = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DsSectionHeader(s.t('ui.inventory.condense.pick_material')),
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
        DsSectionHeader(s.t('ui.inventory.condense.result')),
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
            Text(s.t('ui.inventory.condense.amount'), style: DsText.subtitle()),
            amount('×1', 1, '1'),
            amount(s.t('ui.inventory.condense.max', {'n': max}), null, 'all'),
          ],
        ),
      ],
    );
  }
}
