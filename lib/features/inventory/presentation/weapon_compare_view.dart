import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/panel_frame.dart';
import '../../../app/theme/proto_colors.dart';
import '../../../app/theme/proto_markup.dart';
import '../../../app/theme/retro_text.dart';
import '../../../app/theme/retro_theme.dart';
import '../../../game_engine/models/attributes.dart';
import '../../../game_engine/models/item.dart';
import '../../../game_engine/models/player_profile.dart';
import '../../../game_engine/models/session_action.dart';
import '../../../game_engine/rules/progression_rules.dart';
import '../domain/item_text.dart';
import '../domain/weapon_compare.dart';
import 'shop_sections.dart';
import 'skill_chip.dart';

/// Comparar armas en el inventario: la comparación (stats + qué cambia),
/// la ficha doble del mouse y la vista COMPARAR A vs B. Ver
/// docs/specs/panels.md § "Comparar armas".

/// Un arma de un dueño (el uid solo no alcanza: los de distintos
/// jugadores pueden repetirse).
class WeaponRef {
  const WeaponRef(this.owner, this.uid);
  final String owner;
  final String uid;

  @override
  bool operator ==(Object other) =>
      other is WeaponRef && other.owner == owner && other.uid == uid;

  @override
  int get hashCode => Object.hash(owner, uid);
}

String _plus(String label, String text) =>
    '${protoColor(ProtoColors.green, '+ $label:')} $text';
String _minus(String label, String text) =>
    '${protoColor(ProtoColors.red, '- $label:')} $text';
String _mods(List<String> l) => l
    .map((m) => '<span style="color:$kModHex">${protoEsc(m)}</span>')
    .join(', ');
String _passive(String t) =>
    '<span style="color:$kPassiveHex">${protoEsc(t)}</span>';

/// Stats finales de A → B y qué cambia ([WeaponComparison]).
class ComparisonDelta extends StatelessWidget {
  const ComparisonDelta({
    super.key,
    required this.rules,
    required this.cmp,
    required this.level,
    required this.attributes,
    this.title,
  });

  final ProgressionRules rules;
  final WeaponComparison cmp;
  final int level;
  final PlayerAttributes attributes;

  /// Encabezado (markup), p. ej. `Si la equipas:`.
  final String? title;

  @override
  Widget build(BuildContext context) {
    final lines = <String>[
      if (cmp.skillsGained.isNotEmpty)
        _plus('Habilidad', protoEsc(cmp.skillsGained.join(', '))),
      if (cmp.skillsLost.isNotEmpty)
        _minus('Habilidad', protoEsc(cmp.skillsLost.join(', '))),
      if (cmp.modsGained.isNotEmpty) _plus('Mod', _mods(cmp.modsGained)),
      if (cmp.modsLost.isNotEmpty) _minus('Mod', _mods(cmp.modsLost)),
      if (cmp.passiveChanged && cmp.passiveAfter != null)
        _plus('Pasiva', _passive(cmp.passiveAfter!)),
      if (cmp.passiveChanged && cmp.passiveBefore != null)
        _minus('Pasiva', _passive(cmp.passiveBefore!)),
      if (cmp.ultChanged)
        protoColor(ProtoColors.pink,
            'ULT: ${protoEsc(cmp.ultBefore ?? '—')} → ${protoEsc(cmp.ultAfter ?? '—')}'),
    ];
    final w = rules.items.baseOf(cmp.to);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          ProtoText(title!, style: const TextStyle(color: ProtoColors.sky)),
        if (cmp.same)
          ProtoText(protoColor(ProtoColors.dim, 'Es la misma arma.'))
        else ...[
          Wrap(
            spacing: 16,
            children: [for (final s in cmp.stats) _StatDeltaText(s)],
          ),
          const SizedBox(height: 4),
          ProtoText(lines.isEmpty
              ? protoColor(
                  ProtoColors.dim, 'Mismas habilidades, mods y pasiva.')
              : lines.join('<br>')),
        ],
        if (w != null) ProtoText(requirementsLineMarkup(w, level, attributes)),
        if (!cmp.meetsRequirements)
          ProtoText(protoColor(ProtoColors.red,
              'No cumples los requisitos: hoy no podrías equiparla.')),
      ],
    );
  }
}

/// `ATQ 21 → 30 +9 ▲` (verde y ▲ si mejora, rojo y ▼ si empeora; sin
/// cambio, dim).
class _StatDeltaText extends StatelessWidget {
  const _StatDeltaText(this.s);
  final StatDelta s;

  @override
  Widget build(BuildContext context) {
    if (!s.changed) {
      return Text(retroText('${s.label} ${s.format(s.before)}'),
          style: const TextStyle(color: ProtoColors.dim));
    }
    final c = s.better ? ProtoColors.green : ProtoColors.red;
    // ▲ mejora / ▼ empeora: no solo el color (daltonismo).
    return Text.rich(TextSpan(children: [
      TextSpan(text: retroText('${s.label} ${s.format(s.before)}')),
      TextSpan(
          style: TextStyle(color: c),
          children: symbolSpans(retroText(
              ' → ${s.format(s.after)} ${s.diffText} ${s.better ? '▲' : '▼'}'))),
    ]));
  }
}

/// Ficha de un arma sin la línea de ATQ/MAG (la comparación ya la dice),
/// con un rótulo arriba.
class _LabeledCard extends StatelessWidget {
  const _LabeledCard({
    required this.rules,
    required this.item,
    required this.level,
    required this.attributes,
    this.label,
  });

  final ProgressionRules rules;
  final ItemInstance item;
  final int level;
  final PlayerAttributes attributes;
  final String? label;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label != null) ProtoText(label!),
          ProtoText(itemTooltipMarkup(rules, item,
              level: level, attributes: attributes)),
        ],
      );
}

/// Ficha del mouse: [item] a la izquierda, la equipada ([equipped],
/// rótulo `EQUIPADA`) a la derecha y `Si la equipas:` debajo.
class HoverCompareCard extends StatelessWidget {
  const HoverCompareCard({
    super.key,
    required this.rules,
    required this.viewer,
    required this.item,
    required this.attributes,
    this.ownerName,
  });

  static const cardWidth = 340.0;

  final ProgressionRules rules;
  final PlayerProfile viewer;
  final ItemInstance item;
  final PlayerAttributes attributes;

  /// Dueño si no es el jugador local.
  final String? ownerName;

  /// Desde este agrandamiento del texto la ficha va en dos columnas
  /// (arma | comparación) sin la equipada al lado: con las tres no entra
  /// en 720 px de alto.
  static const compactFrom = 1.5;

  @override
  Widget build(BuildContext context) {
    final eq = rules.equippedItem(viewer);
    final cmp = compareWeapons(rules, viewer, to: item, attributes: attributes);
    final f = RetroType.factorOf(context);
    // Dos tarjetas + separación dentro de la pantalla (márgenes, padding
    // y borde de la caja del tip).
    final room = (MediaQuery.sizeOf(context).width - 16 - 24 - 16) / 2;
    final width = RetroType.width(context, cardWidth).clamp(0.0, room);
    final card = _LabeledCard(
        rules: rules,
        item: item,
        level: viewer.level,
        attributes: attributes,
        label: ownerName == null
            ? null
            : protoColor(ProtoColors.dim, 'de ${protoEsc(ownerName!)}'));
    final delta = ComparisonDelta(
      key: const ValueKey('inv-cmp-tip-delta'),
      rules: rules,
      cmp: cmp,
      level: viewer.level,
      attributes: attributes,
      title: 'Si la equipas:',
    );
    final equipped = eq == null
        ? ProtoText(protoColor(ProtoColors.dim, 'Sin arma'))
        : _LabeledCard(
            rules: rules,
            item: eq,
            level: viewer.level,
            attributes: attributes,
            label: '<b style="color:#ffd166">EQUIPADA</b>');
    if (f >= compactFrom) {
      // Texto muy grande: el arma y, al lado, qué cambia respecto de la
      // equipada (solo su nombre).
      return SizedBox(
        key: const ValueKey('inv-cmp-tip'),
        width: width * 2 + 16,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: width, child: card),
            const SizedBox(width: 16),
            SizedBox(
              width: width,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  KeyedSubtree(
                    key: const ValueKey('inv-cmp-tip-equipped'),
                    child: ProtoText(eq == null
                        ? protoColor(ProtoColors.dim, 'Sin arma')
                        : '<b style="color:#ffd166">EQUIPADA</b> '
                            '${itemNameMarkup(rules, eq)}'),
                  ),
                  const SizedBox(height: 6),
                  delta,
                ],
              ),
            ),
          ],
        ),
      );
    }
    return SizedBox(
      key: const ValueKey('inv-cmp-tip'),
      width: width * 2 + 16,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: width, child: card),
              const SizedBox(width: 16),
              SizedBox(
                key: const ValueKey('inv-cmp-tip-equipped'),
                width: width,
                child: equipped,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Container(height: 2, color: ProtoColors.panelBorder),
          const SizedBox(height: 6),
          delta,
        ],
      ),
    );
  }
}

/// Vista COMPARAR: A y B lado a lado, la comparación A → B para el
/// jugador local y las acciones de las armas propias. `Esc` / CERRAR
/// llaman a [onClose]; si A o B dejan de existir, también.
class WeaponCompareView extends StatefulWidget {
  const WeaponCompareView({
    super.key,
    required this.shop,
    required this.a,
    required this.b,
    required this.onClose,
    required this.onSwap,
    this.pending = const {},
  });

  final ShopContext shop;
  final WeaponRef a;
  final WeaponRef b;
  final VoidCallback onClose;
  final VoidCallback onSwap;
  final Map<Attribute, int> pending;

  @override
  State<WeaponCompareView> createState() => _WeaponCompareViewState();
}

class _WeaponCompareViewState extends State<WeaponCompareView> {
  final _focus = FocusNode(debugLabel: 'compare');

  /// Confirmación pendiente: (letra, operación).
  (String, CraftOp)? _confirm;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is KeyDownEvent && e.logicalKey == LogicalKeyboardKey.escape) {
      if (_confirm != null) {
        setState(() => _confirm = null);
      } else {
        widget.onClose();
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _closeLater() {
    if (_closing) return;
    _closing = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onClose();
    });
  }

  @override
  Widget build(BuildContext context) {
    final shop = widget.shop;
    final rules = shop.rules;
    final session = shop.view.session;
    final me = shop.view.actor!;
    final viewer = me.profile;
    final attrs = viewer.attributes.add(widget.pending);
    ItemInstance? find(WeaponRef r) =>
        session.players[r.owner]?.profile.itemByUid(r.uid);
    final a = find(widget.a);
    final b = find(widget.b);
    if (a == null || b == null) {
      _closeLater();
      return const SizedBox.shrink();
    }
    final cmp =
        compareWeapons(rules, viewer, from: a, to: b, attributes: attrs);

    Widget column(String letter, WeaponRef ref, ItemInstance it) {
      final owner = session.players[ref.owner];
      final mine = ref.owner == me.id;
      final using = mine && rules.equippedItem(viewer)?.uid == it.uid;
      final k = letter.toLowerCase();
      final g = shop.guards;
      return Expanded(
        child: Container(
          key: ValueKey('cmp-card-$k'),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            border: Border.all(
                color: ProtoColors.panelBorder,
                width: RetroTheme.thinBorderWidth),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ProtoText('<b style="color:#ffd166">$letter</b>'
                  '${mine ? '' : ' ${protoColor(ProtoColors.dim, 'de ${protoEsc(owner?.name ?? '?')}')}'}'
                  '${using ? ' ${protoColor(ProtoColors.orange, 'EQUIPADA')}' : ''}'),
              const SizedBox(height: 4),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ProtoText(itemTooltipMarkup(rules, it,
                          level: viewer.level,
                          attributes: attrs,
                          skills: false)),
                      // Cada habilidad con su ficha (mouse / foco).
                      SkillChips(rules: rules, item: it),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 6,
                children: !mine
                    ? [
                        const Text('Solo lectura',
                            style: TextStyle(color: ProtoColors.dim)),
                      ]
                    : [
                        PanelButton('DESARMAR',
                            key: ValueKey('cmp-salvage-$k'),
                            reason: g.craft(
                                viewer, CraftAction(CraftOp.salvage, it.uid)),
                            onPressed: () => setState(
                                () => _confirm = (letter, CraftOp.salvage))),
                        PanelButton('VENDER ₵${rules.crafting.sellPrice(it)}',
                            key: ValueKey('cmp-sell-$k'),
                            reason: g.craft(
                                viewer, CraftAction(CraftOp.sell, it.uid)),
                            onPressed: () => setState(
                                () => _confirm = (letter, CraftOp.sell))),
                        if (!using)
                          PanelButton('EQUIPAR $letter',
                              key: ValueKey('cmp-equip-$k'),
                              accent: ProtoColors.green,
                              reason: g.equip(viewer, it.uid,
                                  pending: widget.pending),
                              onPressed: () => shop.controller.equip(it.uid)),
                      ],
              ),
            ],
          ),
        ),
      );
    }

    final footer = <Widget>[];
    final confirm = _confirm;
    if (confirm != null) {
      final it = confirm.$1 == 'A' ? a : b;
      final op = confirm.$2;
      final act = CraftAction(op, it.uid);
      final r = shop.guards.craftPreview(viewer, act);
      final sell = op == CraftOp.sell;
      footer.addAll([
        Expanded(
          child: ProtoText(
              key: const ValueKey('cmp-craft-question'),
              '¿${sell ? 'Vender' : 'Desarmar'} ${confirm.$1}: '
              '<b>${protoEsc(rules.items.displayName(it))}</b>? '
              'Recibes ${protoColor(ProtoColors.green, protoEsc(gainsText(credits: r.gainedCredits, materials: r.gainedMaterials, chances: r.outcomes)))}. '
              '${protoColor(ProtoColors.red, 'El arma se destruye.')}'
              '${r.lost.isEmpty ? '' : ' ${protoColor(ProtoColors.orange, 'Se pierde: ${protoEsc(r.lost.join(', '))}')}'}'),
        ),
        const SizedBox(width: 8),
        PanelButton('CANCELAR',
            key: const ValueKey('cmp-craft-cancel'),
            onPressed: () => setState(() => _confirm = null)),
        const SizedBox(width: 8),
        PanelButton(sell ? 'VENDER ₵${r.gainedCredits}' : 'DESARMAR',
            key: const ValueKey('cmp-craft-confirm'),
            accent: ProtoColors.red,
            reason: shop.guards.craft(viewer, act), onPressed: () {
          shop.controller.craft(act);
          setState(() => _confirm = null);
        }),
      ]);
    } else {
      footer.addAll([
        const Spacer(),
        PanelButton('INTERCAMBIAR A/B',
            key: const ValueKey('cmp-swap'), onPressed: widget.onSwap),
        const SizedBox(width: 8),
        PanelButton('CERRAR COMPARACIÓN [ESC]',
            key: const ValueKey('cmp-close'), onPressed: widget.onClose),
      ]);
    }

    return Focus(
      focusNode: _focus,
      onKeyEvent: _onKey,
      child: Column(
        key: const ValueKey('cmp-view'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ProtoText('<b style="color:#ffd166">COMPARAR</b> '
              '${protoColor(ProtoColors.dim, '· Si equiparas B en vez de A')}'),
          const SizedBox(height: 6),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                column('A', widget.a, a),
                const SizedBox(width: 12),
                column('B', widget.b, b),
              ],
            ),
          ),
          const SizedBox(height: 6),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 150),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                border: Border.all(
                    color: ProtoColors.panelBorder,
                    width: RetroTheme.thinBorderWidth),
              ),
              child: SingleChildScrollView(
                child: ComparisonDelta(
                  key: const ValueKey('cmp-delta'),
                  rules: rules,
                  cmp: cmp,
                  level: viewer.level,
                  attributes: attrs,
                  title: 'A → B',
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(children: footer),
        ],
      ),
    );
  }
}
