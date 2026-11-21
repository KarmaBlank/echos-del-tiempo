import 'package:material_ui/material_ui.dart';

import '../../../app/design/design.dart';
import '../../../app/design/ds_layout_host.dart';
import '../../../app/theme/proto_colors.dart';
import '../../../app/theme/proto_markup.dart';
import '../../../game_engine/models/item.dart';
import '../../../game_engine/models/player_profile.dart';
import '../../../game_engine/models/session_action.dart';
import '../../../core/layout/layout_doc.dart';
import '../../../game_engine/rules/craft_rules.dart';
import 'craft_layout.dart';
import 'shop_sections.dart';

/// CONDENSAR (mesa de fusión, v0.15; materials_economy.md § 4.3): una
/// tarjeta por receta (10 Esquirlas → 1 Cristal, 10 Cristales → 1
/// Prisma) con lo que tienes, x1 / x5 / TODO y una confirmación con lo
/// que gastas y obtienes. Sin azar y sin vuelta atrás; el host valida
/// los fondos (`CraftOp.condense`).
class CondensePanel extends StatefulWidget {
  const CondensePanel(
      {super.key,
      required this.shop,
      required this.onBack,
      this.layout,
      this.layoutHooks,
      this.initialPending});

  final ShopContext shop;
  final VoidCallback onBack;

  /// Layout fijo (Editor → LAYOUT); `null` = el del catálogo
  /// (editor_layout.md § 6).
  final LayoutDoc? layout;
  final DsLayoutHooks? layoutHooks;

  /// Elección pendiente al abrir (vista previa del Editor).
  final (CraftMaterial, int)? initialPending;

  @override
  State<CondensePanel> createState() => _CondensePanelState();
}

class _CondensePanelState extends State<CondensePanel> {
  /// Elección pendiente de confirmar: material que sale y cuántos.
  late (CraftMaterial, int)? _pending = widget.initialPending;

  ShopContext get shop => widget.shop;

  static String _short(CraftMaterial m) => m.label.split(' ').first;

  CraftAction _action(CraftMaterial out, int n) =>
      CraftAction(CraftOp.condense, out.name, index: n);

  @override
  Widget build(BuildContext context) {
    final p = shop.profile;
    final pending = _pending;
    final a = pending == null ? null : _action(pending.$1, pending.$2);
    final why = a == null ? null : shop.guards.craft(p, a);
    // Slots del layout (editor_layout.md § 6): título, explicación y
    // recetas (fijas); lo de la confirmación solo con algo pendiente.
    final slots = <String, DsSlotBuilder>{
      CondenseLayout.title: (_) => SizedBox(
          width: double.infinity,
          child: DsSectionHeader('Condensar materiales',
              trailing: DsButton('‹ VOLVER',
                  key: const ValueKey('condense-back'),
                  kind: DsButtonKind.ghost,
                  size: DsButtonSize.compact,
                  onPressed: widget.onBack))),
      CondenseLayout.intro: (_) => const ProtoText(
          'Junta lo que te sobra en un material más alto. '
          'Sin azar; <span class="k">no se puede deshacer</span>.'),
      CondenseLayout.recipes: (_) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final out in CraftRules.condensable) ...[
                _recipe(p, out),
                SizedBox(height: DsSpace.sm),
              ],
            ],
          ),
      CondenseLayout.summary: (_) => pending == null
          ? null
          : _summary(pending.$1, pending.$2),
      CondenseLayout.error: (_) => why == null
          ? null
          : ProtoText(
              key: const ValueKey('condense-error'),
              protoColor(ProtoColors.red, 'No se puede: ${protoEsc(why)}')),
      CondenseLayout.go: (_) => a == null
          ? null
          : DsButton('CONDENSAR',
              key: const ValueKey('condense-go'),
              kind: DsButtonKind.primary,
              onPressed: why != null
                  ? null
                  : () {
                      if (shop.controller.craft(a)) {
                        setState(() => _pending = null);
                      }
                    }),
      CondenseLayout.cancel: (_) => a == null
          ? null
          : DsButton('CANCELAR',
              key: const ValueKey('condense-cancel'),
              kind: DsButtonKind.ghost,
              onPressed: () => setState(() => _pending = null)),
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
            if (!r.isEmpty('confirm'))
              DsCard(
                key: const ValueKey('condense-confirm'),
                child: r.region('confirm'),
              ),
          ],
        ),
      ),
    );
  }

  Widget _recipe(PlayerProfile p, CraftMaterial out) {
    final (from, need, cr) = CraftRules.condenseRecipe(out)!;
    final max = CraftRules.condenseMax(p, out);
    final full = p.material(out) >= CraftMaterial.maxStack;
    final fromFull = p.material(from) >= CraftMaterial.maxStack;
    Widget amount(String label, int n, String key) => DsButton(label,
        key: ValueKey('condense-${out.name}-$key'),
        size: DsButtonSize.compact,
        selected: _pending == (out, n),
        onPressed: n < 1 || n > max
            ? null
            : () => setState(() => _pending = (out, n)));
    return DsCard(
      key: ValueKey('condense-card-${out.name}'),
      selected: _pending?.$1 == out,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProtoText(
              '<span class="k">$need ${protoEsc(_short(from))} + ₵$cr</span> → '
              '1 ${protoEsc(out.label)}'),
          ProtoText(
              key: ValueKey('condense-have-${out.name}'),
              'Tienes ${p.material(from)} ${protoEsc(_short(from))} · '
              '${p.material(out)} ${protoEsc(_short(out))} · ₵${p.credits}'
              ' — alcanza para <span class="k">$max</span>'),
          if (fromFull)
            ProtoText(protoColor(ProtoColors.gold,
                'Pila de ${protoEsc(_short(from))} llena: condensa para no '
                'perder lo que caiga.')),
          if (full)
            ProtoText(protoColor(ProtoColors.red,
                'Pila de ${protoEsc(_short(out))} llena '
                '(tope ${CraftMaterial.maxStack}).')),
          SizedBox(height: DsSpace.xs),
          Wrap(spacing: DsSpace.sm, runSpacing: DsSpace.xs, children: [
            amount('x1', 1, '1'),
            amount('x5', 5, '5'),
            amount('TODO ($max)', max, 'all'),
          ]),
        ],
      ),
    );
  }

  Widget _summary(CraftMaterial out, int n) {
    final (from, need, cr) = CraftRules.condenseRecipe(out)!;
    return ProtoText(
        key: const ValueKey('condense-summary'),
        'Gastas <span class="k">${need * n} ${protoEsc(from.label)}</span> y '
        '<span class="k">₵${cr * n}</span>.<br>'
        'Obtienes <span class="k">$n ${protoEsc(out.label)}</span>.<br>'
        '${protoColor(ProtoColors.gold, 'No se puede deshacer.')}');
  }
}
