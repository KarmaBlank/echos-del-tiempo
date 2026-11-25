import 'package:material_ui/material_ui.dart';

import '../../../app/design/design.dart';
import '../../../game_engine/models/eco.dart';
import '../../../game_engine/rules/progression_rules.dart';
import '../../inventory/presentation/item_widgets.dart';

/// Una casilla de la fusión: el Eco elegido (o `null`) y su nombre.
typedef EcoFuseSlot = ({EcoItem? eco, String label});

/// Subpestaña FUSIONAR del Portal (ecos_atlas.md § 4.2): grilla de Ecos
/// estilo INVENTARIO a la izquierda y, a la derecha, las casillas elegidas,
/// lo que saldría y FUSIONAR. Solo dibuja: textos, estado y acciones
/// llegan por parámetros.
class EcoFusionView extends StatelessWidget {
  const EcoFusionView({
    super.key,
    required this.rules,
    required this.ecos,
    required this.selected,
    required this.onToggle,
    required this.title,
    required this.hint,
    required this.slots,
    required this.resultTitle,
    required this.resultLines,
    required this.fuseLabel,
    required this.clearLabel,
    required this.onFuse,
    required this.onClear,
    this.fuseReason,
    this.empty,
  });

  final ProgressionRules rules;
  final List<EcoItem> ecos;
  final List<String> selected;
  final ValueChanged<String> onToggle;
  final String title;
  final String hint;
  final List<EcoFuseSlot> slots;
  final String resultTitle;

  /// Lo que saldría (tier, zona/s, rareza, costo); vacío sin selección.
  final List<String> resultLines;
  final String fuseLabel;
  final String clearLabel;

  /// `null` = FUSIONAR gris.
  final VoidCallback? onFuse;
  final VoidCallback? onClear;

  /// Motivo de FUSIONAR gris (solo si es raro).
  final String? fuseReason;

  /// Texto sin Ecos.
  final String? empty;

  static const detailWidth = 300.0;

  Widget _cell(EcoItem e) => GestureDetector(
        key: ValueKey('eco-fuse-cell-${e.uid}'),
        onTap: () => onToggle(e.uid),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: ItemCell(
              rules: rules,
              content: CellContent.eco(e),
              selected: selected.contains(e.uid),
              size: DsItemCell.size),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final grid = ecos.isEmpty && empty != null
        ? Text(empty!,
            key: const ValueKey('eco-fuse-empty'), style: DsText.detail())
        : Wrap(
            spacing: DsSpace.xs,
            runSpacing: DsSpace.xs,
            children: [for (final e in ecos) _cell(e)],
          );
    final detail = DsDetailPane(
      key: const ValueKey('eco-fuse-detail'),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: DsText.subtitle(DsColors.textTitle)),
          SizedBox(height: DsSpace.xs),
          Text(hint, style: DsText.detail()),
          SizedBox(height: DsSpace.sm),
          for (var i = 0; i < slots.length; i++)
            Padding(
              padding: EdgeInsets.only(bottom: DsSpace.xs),
              child: Row(
                key: ValueKey('eco-fuse-slot-$i'),
                children: [
                  SizedBox.square(
                    dimension: DsItemCell.size,
                    child: slots[i].eco == null
                        ? DecoratedBox(
                            decoration: BoxDecoration(
                                color: DsColors.surfaceSunken,
                                border: Border.all(color: DsColors.border)))
                        : ItemCell(
                            rules: rules,
                            content: CellContent.eco(slots[i].eco!),
                            size: DsItemCell.size),
                  ),
                  SizedBox(width: DsSpace.sm),
                  Expanded(
                    child: Text(slots[i].label,
                        style: slots[i].eco == null
                            ? DsText.detail()
                            : DsText.body()),
                  ),
                ],
              ),
            ),
          SizedBox(height: DsSpace.sm),
          Text(resultTitle, style: DsText.subtitle(DsColors.textSubtitle)),
          SizedBox(height: DsSpace.xs),
          KeyedSubtree(
            key: const ValueKey('eco-fuse-result'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final l in resultLines) Text(l, style: DsText.body()),
              ],
            ),
          ),
        ],
      ),
      actions: Wrap(
        spacing: DsSpace.xs,
        runSpacing: DsSpace.xs,
        children: [
          DsButton(fuseLabel,
              key: const ValueKey('eco-fuse-go'),
              kind: DsButtonKind.primary,
              tooltip: fuseReason,
              onPressed: onFuse),
          DsButton(clearLabel,
              key: const ValueKey('eco-fuse-clear'), onPressed: onClear),
        ],
      ),
    );
    return LayoutBuilder(builder: (context, box) {
      if (box.maxWidth >= 560) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: SingleChildScrollView(child: grid)),
            SizedBox(width: DsSpace.sm),
            SizedBox(
                width: detailWidth, height: box.maxHeight, child: detail),
          ],
        );
      }
      return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [detail, SizedBox(height: DsSpace.sm), grid],
        ),
      );
    });
  }
}
