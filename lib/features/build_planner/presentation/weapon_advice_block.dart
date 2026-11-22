import 'package:material_ui/material_ui.dart';

import '../../../app/design/design.dart';
import '../../../app/theme/retro_text.dart';
import '../../../app/widgets/pixel_icon.dart';
import '../../../game_engine/models/item.dart' show ItemInstance;
import '../../../game_engine/rules/build_guide_rules.dart';
import '../../../game_engine/rules/build_plan_rules.dart';
import 'build_fit_badge.dart' show kPlanColor;

/// Consejo de arma (build_planner.md § 9.4): 4 líneas cortas (tipo
/// ideal, mejor que tenés, mejor para mejorar, para comprar) con su
/// motivo. Solo muestra; las acciones llegan por callbacks y sin
/// callback no hay botón.
class WeaponAdviceBlock extends StatelessWidget {
  const WeaponAdviceBlock({
    super.key,
    required this.advice,
    required this.nameOf,
    this.stashUids = const {},
    this.onEquip,
    this.equipBlocked,
    this.onOpenForge,
    this.onOpenShop,
    this.onChooseType,
  });

  final WeaponAdvice advice;

  /// "Quiero usar": elegir tipo (`null` = el ideal). Sin callback, solo se
  /// muestra el tipo vigente.
  final ValueChanged<String?>? onChooseType;

  /// Nombre a mostrar de un arma tuya.
  final String Function(ItemInstance) nameOf;
  final Set<String> stashUids;

  /// EQUIPAR la mejor que tenés (solo si no está equipada ni en el alijo).
  final ValueChanged<String>? onEquip;

  /// Motivo por el que no se puede equipar ahora (botón gris).
  final String? Function(String uid)? equipBlocked;
  final ValueChanged<String>? onOpenForge;
  final VoidCallback? onOpenShop;

  static String typesLabel(List<String> types) =>
      types.map((t) => t.toUpperCase()).join(' o ');

  Widget _icon(Color c) => PixelIcon(PixelIconKind.sword, size: 12, color: c);

  Widget _button(String label, String key, VoidCallback? onPressed,
          {String? tooltip}) =>
      DsButton(retroText(label),
          key: ValueKey(key),
          size: DsButtonSize.compact,
          tooltip: tooltip,
          onPressed: onPressed);

  @override
  Widget build(BuildContext context) {
    final a = advice;
    final best = a.best;
    final up = a.upgrade;
    final buy = a.buy;
    final attr = a.idealAttribute;
    String owned(WeaponPick w) => [
          nameOf(w.item!),
          if (w.equipped) '(equipada)',
          if (stashUids.contains(w.item!.uid)) '(alijo)',
        ].join(' ');
    // Botones en su propia fila (Wrap): nunca aprietan el texto.
    final actions = <Widget>[
      if (best != null &&
          !best.equipped &&
          !stashUids.contains(best.item!.uid) &&
          onEquip != null)
        () {
          final why = equipBlocked?.call(best.item!.uid);
          return _button('EQUIPAR', 'advice-equip',
              why == null ? () => onEquip!(best.item!.uid) : null,
              tooltip: why);
        }(),
      if (up != null && onOpenForge != null)
        _button('IR A FORJA', 'advice-forge',
            () => onOpenForge!(up.pick.item!.uid)),
      if (buy != null && onOpenShop != null)
        _button('IR A LA ARMERÍA', 'advice-shop', onOpenShop),
    ];
    return Column(
      key: const ValueKey('weapon-advice'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(DsSpace.md, DsSpace.xs, DsSpace.md, 0),
          child: Text(retroText('Consejo de arma'),
              style: DsText.detail(kPlanColor)),
        ),
        DsListRow(
          key: const ValueKey('advice-ideal'),
          compact: true,
          leading: _icon(kPlanColor),
          title: retroText('Tipo ideal: ${typesLabel(a.idealTypes)}'
              '${attr == null ? '' : ' · ${BuildPlanRules.attributeShort(attr)}'}'),
          detail: retroText(a.idealReason),
          detailColor: DsColors.textSecondary,
        ),
        if (onChooseType != null && a.allTypes.isNotEmpty)
          Padding(
            padding: EdgeInsets.symmetric(
                horizontal: DsSpace.md, vertical: DsSpace.xs),
            child: _typePicker(a),
          )
        else if (a.chosenType != null)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: DsSpace.md),
            child: Text(
                retroText('Quiero usar: ${a.chosenType!.toUpperCase()}'),
                style: DsText.detail(kPlanColor)),
          ),
        if (a.howTo.isNotEmpty)
          Padding(
            key: const ValueKey('advice-howto'),
            padding: EdgeInsets.fromLTRB(
                DsSpace.md, DsSpace.xs, DsSpace.md, DsSpace.xs),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                    retroText('Cómo armarlo con ${a.activeType.toUpperCase()}'),
                    style: DsText.detail(kPlanColor)),
                for (final l in a.howTo)
                  Text(retroText('· $l'),
                      style: DsText.detail(DsColors.textSecondary)),
              ],
            ),
          ),
        DsListRow(
          key: const ValueKey('advice-best'),
          compact: true,
          leading: _icon(best == null ? DsColors.textSecondary : DsColors.mp),
          title: retroText(best == null
              ? 'Mejor que tenés: ninguna'
              : 'Mejor que tenés: ${owned(best)}'),
          titleColor:
              best == null || best.meets ? null : DsColors.textSecondary,
          detail: retroText(best == null
              ? 'No tenés armas'
              : best.equipped
                  ? 'Ya la usás · ${best.reasons.first}'
                  : best.reasons.first),
          detailColor:
              best == null || best.meets ? DsColors.mp : DsColors.danger,
          tooltip: best == null ? null : _reasons(best.base.name, best.reasons),
        ),
        if (up != null)
          DsListRow(
            key: const ValueKey('advice-upgrade'),
            compact: true,
            leading: _icon(DsColors.reward),
            title: retroText(
                'Mejor para mejorar: ${owned(up.pick)} +${up.levels} POT'),
            detail: retroText(
                'Le gana a la mejor por ${up.gain.toStringAsFixed(1)} · '
                'forja ${up.credits} créditos'),
            detailColor: DsColors.reward,
            tooltip: _reasons(up.pick.base.name, [
              'Forjada en POT hasta su tope (+${up.levels})',
              ...up.pick.reasons,
            ]),
          ),
        if (buy != null)
          DsListRow(
            key: const ValueKey('advice-buy'),
            compact: true,
            leading: _icon(DsColors.reward),
            title: retroText('Para comprar: ${buy.base.name}'),
            detail: retroText('${buy.base.price} créditos · '
                '${buy.reasons.first}'),
            detailColor: DsColors.textSecondary,
            tooltip: _reasons(buy.base.name, buy.reasons),
          ),
        if (actions.isNotEmpty)
          Padding(
            key: const ValueKey('advice-actions'),
            padding: EdgeInsets.symmetric(
                horizontal: DsSpace.md, vertical: DsSpace.xs),
            child: Wrap(
                spacing: DsSpace.sm, runSpacing: DsSpace.xs, children: actions),
          ),
      ],
    );
  }

  Widget _reasons(String title, List<String> reasons) =>
      DsTooltipCard(title: retroText(title), children: [
        for (final r in reasons) Text(retroText(r), style: DsText.detail()),
      ]);

  /// "Quiero usar: ‹ TIPO ›" (null = el ideal). Wrap: con texto grande o
  /// poco ancho baja de línea en vez de desbordar.
  Widget _typePicker(WeaponAdvice a) {
    final options = <String?>[null, ...a.allTypes];
    final i = options.indexOf(a.chosenType);
    void step(int d) =>
        onChooseType!(options[(i + d + options.length) % options.length]);
    final value = a.chosenType == null
        ? 'IDEAL (${typesLabel(a.idealTypes)})'
        : a.chosenType!.toUpperCase();
    return Wrap(
      key: const ValueKey('advice-type'),
      spacing: DsSpace.xs,
      runSpacing: DsSpace.xs,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(retroText('Quiero usar:'), style: DsText.detail(kPlanColor)),
        DsButton('‹',
            key: const ValueKey('advice-type-prev'),
            size: DsButtonSize.compact,
            tooltip: 'Tipo anterior',
            onPressed: () => step(-1)),
        Text(retroText(value),
            key: const ValueKey('advice-type-value'),
            style: DsText.detail(DsColors.reward)),
        DsButton('›',
            key: const ValueKey('advice-type-next'),
            size: DsButtonSize.compact,
            tooltip: 'Tipo siguiente',
            onPressed: () => step(1)),
      ],
    );
  }
}
