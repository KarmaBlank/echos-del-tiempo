import 'package:material_ui/material_ui.dart';

import '../../../app/theme/panel_frame.dart';
import '../../../app/theme/panel_widgets.dart';
import '../../../app/theme/proto_colors.dart';
import '../../../app/theme/proto_markup.dart';
import '../../../app/theme/retro_text.dart';
import '../../../app/widgets/pixel_icon.dart';
import '../../../game_engine/models/item.dart';
import '../../../game_engine/models/player_profile.dart';
import '../../../game_engine/models/session_action.dart';
import '../../../game_engine/rules/progression_rules.dart';
import '../domain/item_text.dart';
import '../domain/shop_guards.dart';

// LIMPIAR INVENTARIO → ELEGIR A MANO (v0.5.1, loot.md § 21.5,
// panels.md § "Inventario"). Las reglas son las del motor
// (`CraftRules.selectionBlock` / `selectedTargets`); acá solo se arma la
// elección y se dibuja.

/// Rarezas con atajo "seleccionar todo de esta rareza" (los Legendarios
/// solo se eligen uno por uno).
const kCleanAddRarities = [
  Rarity.comun,
  Rarity.magico,
  Rarity.raro,
  Rarity.epico,
];

/// Por qué [token] no se puede elegir con [picked] ya elegidas (`null` =
/// se puede): Ecos, equipada, última inicial.
String? cleanLockReason(ProgressionRules rules, PlayerProfile p, String token,
    Iterable<String> picked) {
  if (p.ecoByUid(token) != null) return 'Los Ecos no se desarman';
  return rules.crafting.selectionBlock(p, token, others: picked);
}

/// La elección sin lo que ya no se puede (vendida, equipada después...),
/// en el mismo orden.
List<String> prunePicked(
    ProgressionRules rules, PlayerProfile p, Iterable<String> picked) {
  final kept = <String>[];
  for (final uid in picked) {
    if (!kept.contains(uid) &&
        rules.crafting.selectionBlock(p, uid, others: kept) == null) {
      kept.add(uid);
    }
  }
  return kept;
}

/// Marca o desmarca [uid] (si está bloqueada, no cambia nada).
List<String> togglePicked(ProgressionRules rules, PlayerProfile p,
    List<String> picked, String uid) {
  if (picked.contains(uid)) return [for (final u in picked) if (u != uid) u];
  if (cleanLockReason(rules, p, uid, picked) != null) return picked;
  return [...picked, uid];
}

/// Suma a la elección todas las armas de rareza [r] que se puedan.
List<String> addRarityPicked(ProgressionRules rules, PlayerProfile p,
    List<String> picked, Rarity r) {
  final out = [...picked];
  for (final it in p.items) {
    if (it.rarity != r || out.contains(it.uid)) continue;
    if (rules.crafting.selectionBlock(p, it.uid, others: out) == null) {
      out.add(it.uid);
    }
  }
  return out;
}

/// Cuántas armas de rareza [r] sumaría [addRarityPicked].
int addableCount(ProgressionRules rules, PlayerProfile p,
        List<String> picked, Rarity r) =>
    addRarityPicked(rules, p, picked, r).length - picked.length;

/// Marca de selección sobre una casilla de la grilla: `✓` verde con borde
/// verde (`clean-check`) si está elegida; candado y atenuada
/// (`clean-lock`) si no se puede elegir.
class CleanCellMark extends StatelessWidget {
  const CleanCellMark({
    super.key,
    required this.child,
    this.picked = false,
    this.locked = false,
  });

  final Widget child;
  final bool picked;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    if (!picked && !locked) return child;
    return Stack(
      children: [
        locked ? Opacity(opacity: 0.45, child: child) : child,
        if (picked)
          Positioned.fill(
            child: IgnorePointer(
              child: Container(
                key: const ValueKey('clean-check'),
                decoration: BoxDecoration(
                  color: const Color(0x3348C774),
                  border: Border.all(color: ProtoColors.green, width: 3),
                ),
                alignment: Alignment.bottomLeft,
                padding: const EdgeInsets.only(left: 2, bottom: 2),
                // La fuente pixel no tiene ✓: el ícono pixel.
                child: const PixelIcon(PixelIconKind.check,
                    size: 14, color: ProtoColors.green),
              ),
            ),
          ),
        if (locked)
          const Positioned(
            left: 2,
            bottom: 2,
            child: IgnorePointer(
              child: PixelIcon(PixelIconKind.lock,
                  key: ValueKey('clean-lock'),
                  size: 14,
                  color: ProtoColors.dim),
            ),
          ),
      ],
    );
  }
}

/// `POR RAREZA` / `ELEGIR A MANO` del limpiador.
class CleanModeToggle extends StatelessWidget {
  const CleanModeToggle(
      {super.key, required this.pick, required this.onChanged});

  final bool pick;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          PanelButton('POR RAREZA',
              key: const ValueKey('inv-clean-mode-rarity'),
              selected: !pick,
              onPressed: () => onChanged(false)),
          PanelButton('ELEGIR A MANO',
              key: const ValueKey('inv-clean-mode-pick'),
              selected: pick,
              onPressed: () => onChanged(true)),
        ],
      );
}

/// El detalle de LIMPIAR INVENTARIO en modo ELEGIR A MANO: verbo,
/// atajos por rareza, `Elegidas: N`, el resumen (vista previa del motor),
/// la lista `Se destruyen:` y `DESARMAR / VENDER N SELECCIONADAS`.
class CleanSelectionPanel extends StatelessWidget {
  const CleanSelectionPanel({
    super.key,
    required this.rules,
    required this.guards,
    required this.profile,
    required this.picked,
    required this.sell,
    required this.onSell,
    required this.onAdd,
    required this.onClear,
    required this.onConfirm,
    required this.onCancel,
    this.onMode,
  });

  final ProgressionRules rules;
  final ShopGuards guards;
  final PlayerProfile profile;
  final List<String> picked;

  /// VENDER (créditos) en vez de DESARMAR (materiales).
  final bool sell;
  final ValueChanged<bool> onSell;
  final ValueChanged<Rarity> onAdd;
  final VoidCallback onClear;
  final ValueChanged<CraftAction> onConfirm;
  final VoidCallback onCancel;

  /// Cambiar a POR RAREZA (`null` = sin el selector de modo).
  final ValueChanged<bool>? onMode;

  CraftAction get action => CraftAction.selected(
      sell ? CraftOp.sellSelected : CraftOp.salvageSelected, picked);

  @override
  Widget build(BuildContext context) {
    final p = profile;
    final a = action;
    final r = guards.craftPreview(p, a);
    final n = picked.length;
    final items = [
      for (final u in picked)
        if (p.itemByUid(u) case final it?) it,
    ];
    final verb = sell ? 'vender' : 'desarmar';
    final summary = n == 0
        ? protoColor(ProtoColors.dim,
            'Toca armas de la grilla (o Espacio) para elegirlas.')
        : 'Vas a $verb ${protoColor(ProtoColors.gold, '$n arma${n == 1 ? '' : 's'}')} → '
            '${protoColor(ProtoColors.green, protoEsc(gainsText(credits: r.gainedCredits, materials: r.gainedMaterials, chances: r.outcomes)))}';
    return PanelDetail(
      footer: [
        PanelButton('CANCELAR',
            key: const ValueKey('inv-clean-cancel'), onPressed: onCancel),
        PanelButton(
            '${sell ? 'VENDER' : 'DESARMAR'} ${n == 0 ? '' : '$n '}'
            'SELECCIONADA${n == 1 ? '' : 'S'}',
            key: const ValueKey('inv-clean-confirm'),
            accent: ProtoColors.red,
            reason: n == 0 ? 'Elige armas' : guards.craft(p, a),
            onPressed: () => onConfirm(a)),
      ],
      children: [
        const Text('LIMPIAR INVENTARIO',
            style: TextStyle(color: ProtoColors.gold)),
        const SizedBox(height: 4),
        if (onMode case final m?) ...[
          CleanModeToggle(pick: true, onChanged: m),
          const SizedBox(height: 6),
        ],
        ProtoText(protoColor(
            ProtoColors.dim,
            'Elige en la grilla las armas a destruir (clic o Espacio). La '
            'equipada y tu última arma inicial tienen candado.')),
        const SizedBox(height: 8),
        Wrap(spacing: 6, runSpacing: 6, children: [
          PanelButton('DESARMAR (materiales)',
              key: const ValueKey('inv-clean-salvage'),
              selected: !sell,
              onPressed: () => onSell(false)),
          PanelButton('VENDER (créditos)',
              key: const ValueKey('inv-clean-sell'),
              selected: sell,
              onPressed: () => onSell(true)),
        ]),
        const SizedBox(height: 6),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final rr in kCleanAddRarities)
            PanelButton(
                '+ ${rarityPlural(rr).toUpperCase()} '
                '(${addableCount(rules, p, picked, rr)})',
                key: ValueKey('inv-clean-add-${rr.name}'),
                onPressed: addableCount(rules, p, picked, rr) == 0
                    ? null
                    : () => onAdd(rr)),
          PanelButton('NINGUNA',
              key: const ValueKey('inv-clean-none'),
              onPressed: n == 0 ? null : onClear),
        ]),
        const SizedBox(height: 8),
        Text(retroText('Elegidas: $n'),
            key: const ValueKey('inv-clean-count'),
            style: const TextStyle(color: ProtoColors.sky)),
        const SizedBox(height: 4),
        ProtoText(summary, key: const ValueKey('inv-clean-summary')),
        if (r.lost.isNotEmpty)
          ProtoText(protoColor(
              ProtoColors.orange, 'Se pierde: ${protoEsc(r.lost.join(', '))}')),
        if (items.isNotEmpty) ...[
          const SizedBox(height: 6),
          ProtoText(
              key: const ValueKey('inv-clean-list'),
              '${protoColor(ProtoColors.red, 'Se destruyen:')}<br>'
              '${[
                for (final it in items)
                  '• ${itemNameMarkup(rules, it)}'
                      '${sell ? ' ₵${rules.crafting.sellPrice(it)}' : ''}'
              ].join('<br>')}'),
        ],
      ],
    );
  }
}
