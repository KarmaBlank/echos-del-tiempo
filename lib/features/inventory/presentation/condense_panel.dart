import 'package:material_ui/material_ui.dart';

import '../../../app/design/design.dart';
import '../../../app/theme/proto_colors.dart';
import '../../../app/theme/proto_markup.dart';
import '../../../game_engine/models/item.dart';
import '../../../game_engine/models/player_profile.dart';
import '../../../game_engine/models/session_action.dart';
import '../../../game_engine/rules/craft_rules.dart';
import 'shop_sections.dart';

/// CONDENSAR (mesa de fusión, v0.15; materials_economy.md § 4.3): una
/// tarjeta por receta (10 Esquirlas → 1 Cristal, 10 Cristales → 1
/// Prisma) con lo que tienes, x1 / x5 / TODO y una confirmación con lo
/// que gastas y obtienes. Sin azar y sin vuelta atrás; el host valida
/// los fondos (`CraftOp.condense`).
class CondensePanel extends StatefulWidget {
  const CondensePanel({super.key, required this.shop, required this.onBack});

  final ShopContext shop;
  final VoidCallback onBack;

  @override
  State<CondensePanel> createState() => _CondensePanelState();
}

class _CondensePanelState extends State<CondensePanel> {
  /// Elección pendiente de confirmar: material que sale y cuántos.
  (CraftMaterial, int)? _pending;

  ShopContext get shop => widget.shop;

  static String _short(CraftMaterial m) => m.label.split(' ').first;

  CraftAction _action(CraftMaterial out, int n) =>
      CraftAction(CraftOp.condense, out.name, index: n);

  @override
  Widget build(BuildContext context) {
    final p = shop.profile;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DsSectionHeader('Condensar materiales',
              trailing: DsButton('‹ VOLVER',
                  key: const ValueKey('condense-back'),
                  kind: DsButtonKind.ghost,
                  size: DsButtonSize.compact,
                  onPressed: widget.onBack)),
          const ProtoText('Junta lo que te sobra en un material más alto. '
              'Sin azar; <span class="k">no se puede deshacer</span>.'),
          SizedBox(height: DsSpace.sm),
          for (final out in CraftRules.condensable) ...[
            _recipe(p, out),
            SizedBox(height: DsSpace.sm),
          ],
          if (_pending case (final out, final n)) _confirm(p, out, n),
        ],
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

  Widget _confirm(PlayerProfile p, CraftMaterial out, int n) {
    final (from, need, cr) = CraftRules.condenseRecipe(out)!;
    final a = _action(out, n);
    final why = shop.guards.craft(p, a);
    return DsCard(
      key: const ValueKey('condense-confirm'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProtoText(
              key: const ValueKey('condense-summary'),
              'Gastas <span class="k">${need * n} ${protoEsc(from.label)}</span> y '
              '<span class="k">₵${cr * n}</span>.<br>'
              'Obtienes <span class="k">$n ${protoEsc(out.label)}</span>.<br>'
              '${protoColor(ProtoColors.gold, 'No se puede deshacer.')}'),
          if (why != null)
            ProtoText(
                key: const ValueKey('condense-error'),
                protoColor(ProtoColors.red, 'No se puede: ${protoEsc(why)}')),
          SizedBox(height: DsSpace.xs),
          Wrap(spacing: DsSpace.sm, children: [
            DsButton('CONDENSAR',
                key: const ValueKey('condense-go'),
                kind: DsButtonKind.primary,
                onPressed: why != null
                    ? null
                    : () {
                        if (shop.controller.craft(a)) {
                          setState(() => _pending = null);
                        }
                      }),
            DsButton('CANCELAR',
                key: const ValueKey('condense-cancel'),
                kind: DsButtonKind.ghost,
                onPressed: () => setState(() => _pending = null)),
          ]),
        ],
      ),
    );
  }
}
