import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/design/design.dart';
import '../../../app/theme/proto_colors.dart';
import '../../../app/theme/proto_markup.dart';
import '../../../app/theme/retro_hover_card.dart';
import '../../../app/theme/retro_text.dart';
import '../../../app/theme/retro_theme.dart';
import '../../../game_engine/models/attributes.dart';
import '../../../game_engine/models/item.dart';
import '../../../game_engine/models/player_profile.dart';
import '../../../game_engine/models/session_action.dart';
import '../../../game_engine/rules/progression_rules.dart';
import '../../../game_engine/rules/weapon_weight.dart';
import '../domain/battle_impact.dart';
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
String _weightTag(WeightClass c) =>
    '<b style="color:${weightClassHex(c)}">${c.label}</b>';
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
      if (cmp.elementChanged)
        'Elemento: ${protoEsc(cmp.elementBefore?.label ?? '—')} → '
            '${protoEsc(cmp.elementAfter?.label ?? '—')}',
      if (cmp.ultChanged)
        protoColor(ProtoColors.pink,
            'ULT: ${protoEsc(cmp.ultBefore ?? '—')} → ${protoEsc(cmp.ultAfter ?? '—')}'),
    ];
    // Peso (panels.md § "Peso del arma"): la categoría si cambia y lo que
    // cambia el turno, con el mismo cálculo que la batalla.
    final speedChanged = (cmp.before.speed - cmp.after.speed).abs() > 1e-6;
    final weightLines = <String>[
      if (cmp.weightClassChanged)
        'Peso: ${_weightTag(cmp.weightClassBefore)} → '
            '${_weightTag(cmp.weightClassAfter)}',
      if (speedChanged) turnIntervalLine(rules, cmp.before, cmp.after.speed),
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
          if (weightLines.isNotEmpty)
            ProtoText(weightLines.join('<br>'),
                key: const ValueKey('cmp-weight')),
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
  _StatDeltaText(this.s) : super(key: ValueKey('cmp-stat-${s.label}'));
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
    this.equipped = false,
  });

  /// Ficha de la equipada (`itemTipParts(equipped:)`).
  final bool equipped;

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
          // Resumen + secciones plegables (ui_style.md § "Tooltips
          // cortos").
          LayoutBuilder(builder: (context, c) {
            final parts = itemTipParts(rules, item,
                level: level, attributes: attributes, equipped: equipped);
            return RetroTipFolds(
                summary: parts.summary,
                sections: parts.sections,
                maxWidth: c.maxWidth.isFinite ? c.maxWidth : 340);
          }),
        ],
      );
}

/// `Si la equipas:` corto del tooltip (ui_style.md § "Tooltips cortos",
/// panels.md § "Comparar armas"): solo las estadísticas que cambian, en
/// una grilla de dos columnas si entra (`ATQ 116 → 120 ▲4`), y el resto
/// (turno, habilidades, mods, pasiva, ULT, requisitos) en `▸ Cambios`.
class CompactComparison extends StatelessWidget {
  const CompactComparison({
    super.key,
    required this.rules,
    required this.cmp,
    required this.level,
    required this.attributes,
    required this.maxWidth,
  });

  final ProgressionRules rules;
  final WeaponComparison cmp;
  final int level;
  final PlayerAttributes attributes;
  final double maxWidth;

  /// Markup de la sección plegada `Cambios` (vacío si no hay nada).
  static String changesMarkup(ProgressionRules rules, WeaponComparison cmp,
      int level, PlayerAttributes attributes) {
    final speedChanged = (cmp.before.speed - cmp.after.speed).abs() > 1e-6;
    final w = rules.items.baseOf(cmp.to);
    return [
      if (cmp.weightClassChanged)
        'Peso: ${_weightTag(cmp.weightClassBefore)} → '
            '${_weightTag(cmp.weightClassAfter)}',
      if (speedChanged) turnIntervalLine(rules, cmp.before, cmp.after.speed),
      if (cmp.skillsGained.isNotEmpty)
        _plus('Habilidad', protoEsc(cmp.skillsGained.join(', '))),
      if (cmp.skillsLost.isNotEmpty)
        _minus('Habilidad', protoEsc(cmp.skillsLost.join(', '))),
      if (cmp.modsGained.isNotEmpty) _plus('Mod', _mods(cmp.modsGained)),
      if (cmp.modsLost.isNotEmpty) _minus('Mod', _mods(cmp.modsLost)),
      // La pasiva y la ULT solo si cambian.
      if (cmp.passiveChanged && cmp.passiveAfter != null)
        _plus('Pasiva', _passive(cmp.passiveAfter!)),
      if (cmp.passiveChanged && cmp.passiveBefore != null)
        _minus('Pasiva', _passive(cmp.passiveBefore!)),
      if (cmp.elementChanged)
        'Elemento: ${protoEsc(cmp.elementBefore?.label ?? '—')} → '
            '${protoEsc(cmp.elementAfter?.label ?? '—')}',
      if (cmp.ultChanged)
        protoColor(ProtoColors.pink,
            'ULT: ${protoEsc(cmp.ultBefore ?? '—')} → ${protoEsc(cmp.ultAfter ?? '—')}'),
      if (w != null && !cmp.meetsRequirements)
        requirementsLineMarkup(w, level, attributes),
    ].join('<br>');
  }

  @override
  Widget build(BuildContext context) {
    final changed = [
      for (final s in cmp.stats)
        if (s.changed) s
    ];
    // Dos columnas si cada una tiene ~20 letras; si no, una.
    final half = (maxWidth - 8) / 2;
    final cellW = half >= RetroType.width(context, 160) ? half : maxWidth;
    final changes = changesMarkup(rules, cmp, level, attributes);
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProtoText(protoColor(ProtoColors.sky, 'Si la equipas:')),
          if (cmp.same)
            ProtoText(protoColor(ProtoColors.dim, 'Es la misma arma.'))
          else if (changed.isEmpty)
            ProtoText(protoColor(ProtoColors.dim, 'Mismas estadísticas.'))
          else
            Wrap(
              spacing: 8,
              children: [
                for (final s in changed)
                  SizedBox(width: cellW, child: _ShortDelta(s)),
              ],
            ),
          if (!cmp.meetsRequirements)
            ProtoText(
                protoColor(ProtoColors.red, 'No cumples los requisitos.')),
          if (!cmp.same && changes.isNotEmpty)
            RetroTipFold(title: 'Cambios', body: changes, maxWidth: maxWidth),
        ],
      ),
    );
  }
}

/// `ATQ 116 → 120 ▲4` (verde ▲ si mejora, rojo ▼ si empeora).
class _ShortDelta extends StatelessWidget {
  _ShortDelta(this.s) : super(key: ValueKey('cmp-stat-${s.label}'));
  final StatDelta s;

  @override
  Widget build(BuildContext context) {
    final c = s.better ? ProtoColors.green : ProtoColors.red;
    final d = s.diffText.replaceFirst(RegExp(r'^[+-]'), '');
    return Text.rich(TextSpan(children: [
      TextSpan(text: retroText('${s.label} ${s.format(s.before)} ')),
      TextSpan(
          style: TextStyle(color: c),
          children: symbolSpans(
              retroText('→ ${s.format(s.after)} ${s.better ? '▲' : '▼'}$d'))),
    ]));
  }
}

/// Ficha del mouse (v0.9.13): una sola columna angosta con [item]
/// (resumen + plegables), ~32 letras que crecen con el texto. Con Shift
/// apretado ([showEquipped], por defecto [RetroHoverCard.shiftHeld]) se
/// suma al lado la ficha de la EQUIPADA (v0.10.1, mismo ancho; los
/// cambios están en la franja de CAMBIOS). Nunca pasa de
/// [maxScreenShare] del ancho de la pantalla (ni de la zona de
/// [RetroTipArea] si la hay).
class HoverCompareCard extends StatelessWidget {
  const HoverCompareCard({
    super.key,
    required this.rules,
    required this.viewer,
    required this.item,
    required this.attributes,
    this.ownerName,
    this.showEquipped,
    this.footer,
  });

  /// Debajo de la ficha y del mismo ancho (p. ej. "★ Tu build"); nunca
  /// la ensancha.
  final Widget? footer;

  /// Ancho de la columna en Normal (~32 letras de VT323).
  static const cardWidth = 180.0;

  /// Parte máxima del ancho de la pantalla que ocupa la ficha.
  static const maxScreenShare = 0.7;

  final ProgressionRules rules;
  final PlayerProfile viewer;
  final ItemInstance item;
  final PlayerAttributes attributes;

  /// Dueño si no es el jugador local.
  final String? ownerName;

  /// Forzar la columna de la equipada (`null` = mientras Shift).
  final bool? showEquipped;

  @override
  Widget build(BuildContext context) {
    final forced = showEquipped;
    if (forced != null) return _card(context, forced);
    return ValueListenableBuilder<bool>(
        valueListenable: RetroHoverCard.shiftHeld,
        builder: (context, shift, _) => _card(context, shift));
  }

  Widget _card(BuildContext context, bool withEquipped) {
    final f = footer;
    final body = _cardBody(context, withEquipped);
    if (f == null) return body;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        body,
        SizedBox(width: body.width, child: f),
      ],
    );
  }

  SizedBox _cardBody(BuildContext context, bool withEquipped) {
    // Dentro de la zona del tooltip (en el inventario, la columna de la
    // grilla): una columna entera sola; con Shift, dos que entren.
    final inArea =
        context.getInheritedWidgetOfExactType<RetroTipArea>() != null;
    final avail =
        MediaQuery.sizeOf(context).width * (inArea ? 1 : maxScreenShare) - 24;
    final room = withEquipped ? (avail - 16) / 2 : avail;
    final width = RetroType.width(context, cardWidth).clamp(0.0, room);
    final card = _LabeledCard(
        rules: rules,
        item: item,
        level: viewer.level,
        attributes: attributes,
        label: ownerName == null
            ? null
            : protoColor(ProtoColors.dim, 'de ${protoEsc(ownerName!)}'));
    if (!withEquipped) {
      return SizedBox(
          key: const ValueKey('inv-cmp-tip'), width: width, child: card);
    }
    // Shift (v0.10.1): al lado, la ficha de la EQUIPADA (la misma de una
    // columna); los cambios ya están en la franja de CAMBIOS.
    final eq = rules.equippedItem(viewer);
    return SizedBox(
      key: const ValueKey('inv-cmp-tip'),
      width: width * 2 + 16,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: width, child: card),
          const SizedBox(width: 16),
          SizedBox(
            key: const ValueKey('inv-cmp-tip-equipped'),
            width: width,
            child: eq == null
                ? ProtoText(protoColor(ProtoColors.dim, 'Sin arma equipada'))
                : _LabeledCard(
                    rules: rules,
                    item: eq,
                    level: viewer.level,
                    attributes: attributes,
                    equipped: true,
                    label: '<b style="color:#ffd166">EQUIPADA</b>'),
          ),
        ],
      ),
    );
  }
}

/// Franja de cambios a la izquierda de la grilla (v0.9.13, panels.md §
/// "Inventario"): una línea corta por stat (`ATQ 19→28 ▲9`, verde ▲ /
/// rojo ▼) con [stats] de [stripStats]; sin arma mirada, los valores
/// actuales en gris.
class ChangeStrip extends StatelessWidget {
  const ChangeStrip({super.key, required this.stats, required this.hovering});

  final List<StatDelta> stats;
  final bool hovering;

  /// Ancho mínimo en Normal (~14 letras).
  static const width = 96.0;

  /// Ancho de la etiqueta de cada línea (en letras, `CRÍT`, `Vida`).
  static const labelEm = 5.0;

  /// Valor más largo posible: con él se mide el ancho para que cada stat
  /// entre en una línea con el texto actual.
  static const _value = '999.9%';

  /// Ancho de la franja con el tamaño de texto actual (v0.10.1): cada
  /// stat en una sola línea ([DsStatLine]), nunca partida.
  static double widthOf(BuildContext context) {
    final scaler = MediaQuery.textScalerOf(context);
    double w(String t, TextStyle st) {
      final tp = TextPainter(
        text: TextSpan(text: t, style: st),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final r = tp.width;
      tp.dispose();
      return r;
    }

    final glyph = RetroType.style(RetroType.glyph);
    final total = RetroType.em(context, labelEm, size: RetroType.body) +
        w(_value, DsText.detail()) +
        w(' → ', glyph) +
        w(_value, DsText.body()) +
        DsSpace.sm +
        w('▲', glyph) +
        w(_value, DsText.body()) +
        2 * DsSpace.xs +
        4;
    final min = RetroType.width(context, width);
    return total > min ? total : min;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('inv-strip'),
      width: widthOf(context),
      padding: EdgeInsets.all(DsSpace.xs),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(hovering ? 'CAMBIOS' : 'ACTUAL', style: DsText.subtitle()),
          SizedBox(height: DsSpace.xs),
          // Una línea por stat; sin arma mirada, solo el valor actual.
          for (final s in stats)
            DsStatLine(retroText(s.label), s.before, s.after,
                key: ValueKey('inv-strip-${s.label}'),
                labelWidth: labelEm,
                format: (x) => retroText(s.format(x)),
                diffFormat: (x) => retroText(
                    StatDelta(s.label, 0, x, kind: s.kind)
                        .diffText
                        .substring(1)),
                higherIsBetter: s.higherIsBetter,
                showChange: hovering),
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

  /// Botón compacto; con [reason] queda deshabilitado y la dice en el
  /// tooltip.
  Widget _btn(String label, String key, String? reason, VoidCallback onTap,
          {DsButtonKind kind = DsButtonKind.secondary,
          Color? accent,
          String? tooltip}) =>
      DsButton(label,
          key: ValueKey(key),
          kind: kind,
          size: DsButtonSize.compact,
          accent: accent,
          tooltip: reason ?? tooltip,
          onPressed: reason == null ? onTap : null);

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
    final attrs = viewer.attributes.add(ProgressionRules.rawOf(widget.pending));
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
          // Superficie sin borde (design_system.md § 6, DsCard).
          padding: EdgeInsets.all(DsSpace.sm),
          color: DsColors.surface,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ProtoText('<span style="color:#ffd166">$letter</span>'
                  '${mine ? '' : ' ${protoColor(ProtoColors.dim, 'de ${protoEsc(owner?.name ?? '?')}')}'}'
                  '${using ? ' ${protoColor(ProtoColors.orange, 'EQUIPADA')}' : ''}'),
              SizedBox(height: DsSpace.xs),
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
              SizedBox(height: DsSpace.sm),
              Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: DsSpace.xs,
                runSpacing: DsSpace.xs,
                children: !mine
                    ? [Text('Solo lectura', style: DsText.detail())]
                    : [
                        _btn(
                            'DESARMAR',
                            'cmp-salvage-$k',
                            g.craft(
                                viewer, CraftAction(CraftOp.salvage, it.uid)),
                            () => setState(
                                () => _confirm = (letter, CraftOp.salvage))),
                        _btn(
                            'VENDER ₵${rules.crafting.sellPrice(it)}',
                            'cmp-sell-$k',
                            g.craft(viewer, CraftAction(CraftOp.sell, it.uid)),
                            () => setState(
                                () => _confirm = (letter, CraftOp.sell))),
                        if (!using)
                          _btn(
                              'EQUIPAR $letter',
                              'cmp-equip-$k',
                              g.equip(viewer, it.uid, pending: widget.pending),
                              () => shop.controller.equip(it.uid),
                              kind: DsButtonKind.primary),
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
              '${protoEsc(rules.items.displayName(it))}? '
              'Recibes ${protoColor(ProtoColors.green, protoEsc(gainsText(credits: r.gainedCredits, materials: r.gainedMaterials, chances: r.outcomes)))}. '
              '${protoColor(ProtoColors.red, 'El arma se destruye.')}'
              '${r.lost.isEmpty ? '' : ' ${protoColor(ProtoColors.orange, 'Se pierde: ${protoEsc(r.lost.join(', '))}')}'}'),
        ),
        SizedBox(width: DsSpace.sm),
        _btn('CANCELAR', 'cmp-craft-cancel', null,
            () => setState(() => _confirm = null)),
        SizedBox(width: DsSpace.xs),
        _btn(sell ? 'VENDER ₵${r.gainedCredits}' : 'DESARMAR',
            'cmp-craft-confirm', shop.guards.craft(viewer, act), () {
          shop.controller.craft(act);
          setState(() => _confirm = null);
        }, accent: DsColors.danger),
      ]);
    } else {
      footer.addAll([
        const Spacer(),
        _btn('INTERCAMBIAR A/B', 'cmp-swap', null, widget.onSwap),
        SizedBox(width: DsSpace.xs),
        _btn('CERRAR [ESC]', 'cmp-close', null, widget.onClose,
            tooltip: 'Cerrar la comparación'),
      ]);
    }

    return Focus(
      focusNode: _focus,
      onKeyEvent: _onKey,
      child: Column(
        key: const ValueKey('cmp-view'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text.rich(TextSpan(children: [
            TextSpan(text: 'COMPARAR', style: DsText.subtitle()),
            TextSpan(
                text: '  Si equiparas B en vez de A', style: DsText.detail()),
          ])),
          SizedBox(height: DsSpace.sm),
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
          SizedBox(height: DsSpace.sm),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 150),
            child: Container(
              padding: EdgeInsets.all(DsSpace.sm),
              color: DsColors.surface,
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
          SizedBox(height: DsSpace.sm),
          Row(children: footer),
        ],
      ),
    );
  }
}
