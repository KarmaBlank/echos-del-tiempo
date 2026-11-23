import 'package:material_ui/material_ui.dart';

import '../../../../app/design/design.dart';
import '../../../../game_engine/data/construction_catalog.dart';
import '../../../../game_engine/data/fishing_catalog.dart';
import '../../../../game_engine/models/world_save.dart';
import '../../../../game_engine/rules/town_rules.dart';
import '../session_controller.dart';
import 'fishing_widgets.dart' show fishRarityColor;

/// Interfaz de la edición del pueblo (town_editor.md § 1): barra de
/// arriba con LISTO, y a la derecha el menú del paso en curso (ampliar,
/// qué construir, opciones de un lago o una huerta, soltar peces,
/// confirmar el borrado). El mapa (cámara, fantasmas) lo dibuja
/// `TownEditLayer`.
class TownEditOverlay extends StatelessWidget {
  const TownEditOverlay({super.key, required this.controller});

  final SessionController controller;

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final e = c.townEdit;
    if (e == null) return const SizedBox.shrink();
    final menu = _menu(c, e);
    final info = _info(c, e);
    // Barra de arriba a todo el ancho y, debajo a la derecha, una sola
    // columna: el menú del paso y el panel de info de lo que está bajo
    // el mouse (town_editor.md § 1.3). Nada se superpone.
    return LayoutBuilder(builder: (context, box) {
      final side = (box.maxWidth * 0.3).clamp(240.0, 320.0);
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          key: const ValueKey('town-edit-bar'),
          color: DsColors.background,
          padding: EdgeInsets.symmetric(
              horizontal: DsSpace.md, vertical: DsSpace.xs),
          child: Row(children: [
            Text('EDICIÓN DEL PUEBLO', style: DsText.title()),
            SizedBox(width: DsSpace.md),
            Expanded(
                child: Text(_hint(c, e),
                    key: const ValueKey('town-edit-hint'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: DsText.detail())),
            SizedBox(width: DsSpace.md),
            DsButton('LISTO [ESC]',
                key: const ValueKey('town-edit-done'),
                size: DsButtonSize.compact,
                kind: DsButtonKind.primary,
                onPressed: c.exitTownEdit),
          ]),
        ),
        Expanded(
          child: Align(
            alignment: Alignment.topRight,
            child: Padding(
              padding: EdgeInsets.all(DsSpace.sm),
              child: SizedBox(
                width: side,
                child: SingleChildScrollView(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (menu != null)
                          Container(
                            key: const ValueKey('town-edit-menu'),
                            color: DsColors.background,
                            padding: EdgeInsets.all(DsSpace.sm),
                            child: menu,
                          ),
                        if (menu != null && info != null)
                          SizedBox(height: DsSpace.xs),
                        if (info != null)
                          Container(
                            key: const ValueKey('town-edit-hover'),
                            color: DsColors.background,
                            padding: EdgeInsets.all(DsSpace.sm),
                            child: info,
                          ),
                      ]),
                ),
              ),
            ),
          ),
        ),
      ]);
    });
  }

  /// Info de lo que está bajo el mouse: franja (con su costo) o
  /// construcción. `null` si no hay nada o si ya lo muestra el menú.
  static Widget? _info(SessionController c, TownEdit e) {
    if (e.step != TownEditStep.browse && e.step != TownEditStep.side) {
      return null;
    }
    final town = c.town;
    if (e.hoverSide case final side?) {
      if (e.step == TownEditStep.side && e.side == side) return null;
      final why = c.cannotExpandTown(side);
      return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            DsSectionHeader('AMPLIAR AL ${side.label}'),
            Text(TownRules.costText(TownRules.cost(town.expansions + 1)),
                key: const ValueKey('town-edit-hover-cost'),
                style: DsText.detail()),
            Text(why ?? 'Clic para ampliar.', style: DsText.detail()),
          ]);
    }
    if (e.step != TownEditStep.browse) return null;
    final b = town.builds.where((b) => b.id == e.hoverBuild).firstOrNull;
    if (b == null) return null;
    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          DsSectionHeader(b.kind.label),
          Text(
              b.kind == BuildKind.lago
                  ? TownRules.lakeSignText(town, b)
                  : TownRules.farmSignText(b),
              style: DsText.detail()),
          Text('Clic para ver opciones.', style: DsText.detail()),
        ]);
  }

  static String _hint(SessionController c, TownEdit e) => switch (e.step) {
        TownEditStep.moving ||
        TownEditStep.placing =>
          c.editGhostError ?? 'Clic para dejarlo acá',
        _ => 'WASD o arrastrar: cámara · rueda: zoom · clic: elegir',
      };

  Widget? _menu(SessionController c, TownEdit e) {
    final town = c.town;
    final b = c.editSelected;
    Widget cancel() => DsButton('CANCELAR',
        key: const ValueKey('town-edit-cancel'),
        size: DsButtonSize.compact,
        onPressed: c.editBack);
    Widget col(List<Widget> ch) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: ch);
    switch (e.step) {
      case TownEditStep.browse:
        return null;
      case TownEditStep.side:
        final side = e.side!;
        final why = c.cannotExpandTown(side);
        return col([
          DsSectionHeader('AMPLIAR AL ${side.label}',
              trailing:
                  DsBadge('${town.expansions}/${TownRules.maxExpansions}')),
          Text(
              'Suma una franja de $kTownStrip tiles de terreno libre. '
              '${TownRules.costText(TownRules.cost(town.expansions + 1))}',
              style: DsText.detail()),
          SizedBox(height: DsSpace.xs),
          Row(children: [
            DsButton('AMPLIAR',
                key: const ValueKey('town-edit-expand'),
                size: DsButtonSize.compact,
                kind: DsButtonKind.primary,
                tooltip: why,
                onPressed: why == null
                    ? () {
                        if (c.expandTown(side)) c.editBack();
                      }
                    : null),
            SizedBox(width: DsSpace.xs),
            cancel(),
          ]),
        ]);
      case TownEditStep.choose:
        return col([
          const DsSectionHeader('CONSTRUIR'),
          for (final d in kConstructions)
            DsListRow(
              key: ValueKey('town-edit-build-${d.id}'),
              compact: true,
              title: d.name,
              detail: '${d.w}×${d.h} · ${d.detail}',
              onTap: () => c.editChoose(d.id),
            ),
          SizedBox(height: DsSpace.xs),
          Align(alignment: Alignment.centerLeft, child: cancel()),
        ]);
      case TownEditStep.options:
        if (b == null) return null;
        final lake = b.kind == BuildKind.lago;
        return col([
          DsSectionHeader(b.kind.label),
          Text(
              lake
                  ? TownRules.lakeSignText(town, b)
                  : TownRules.farmSignText(b),
              key: const ValueKey('town-edit-info'),
              style: DsText.detail()),
          SizedBox(height: DsSpace.xs),
          Wrap(spacing: DsSpace.xs, runSpacing: DsSpace.xs, children: [
            if (lake)
              DsButton('AGREGAR ESPECIES',
                  key: const ValueKey('town-edit-stock'),
                  size: DsButtonSize.compact,
                  onPressed: () => c.editStep(TownEditStep.stocking)),
            DsButton('MOVER',
                key: const ValueKey('town-edit-move'),
                size: DsButtonSize.compact,
                onPressed: c.editStartMove),
            DsButton(lake ? 'BORRAR LAGO' : 'BORRAR',
                key: const ValueKey('town-edit-delete'),
                size: DsButtonSize.compact,
                onPressed: () => c.editStep(TownEditStep.confirmDelete)),
            cancel(),
          ]),
        ]);
      case TownEditStep.stocking:
        if (b == null) return null;
        final p = c.view?.me?.profile;
        final cap = TownRules.lakeCapacity(b);
        final fish = [
          for (final f in kFish.values)
            if ((p?.life.count(f.id) ?? 0) > 0 && f.biome != kWaterJunkBiome) f
        ];
        return col([
          DsSectionHeader('AGREGAR ESPECIES',
              trailing: DsBadge('${b.stockTotal}/$cap',
                  key: const ValueKey('town-edit-lake-count'))),
          Text(
              'Soltá peces de tu bolsa en este lago: esa especie sale más '
              'seguido y, con dos o más, cría al ganar misiones.',
              style: DsText.detail()),
          for (final en in b.stock.entries)
            if (kFish[en.key] case final f?)
              DsListRow(
                compact: true,
                title: '${f.name} ×${en.value}',
                titleColor: fishRarityColor(f.rarity),
                detail: en.value >= 2 ? 'Cría' : 'Sola',
              ),
          if (fish.isEmpty)
            Text('No tenés peces en la bolsa.', style: DsText.detail()),
          for (final f in fish)
            DsListRow(
              key: ValueKey('town-edit-release-${f.id}'),
              compact: true,
              title: '${f.name} (tenés ${p?.life.count(f.id) ?? 0})',
              titleColor: fishRarityColor(f.rarity),
              trailing: DsButton('SOLTAR',
                  key: ValueKey('town-edit-release-btn-${f.id}'),
                  size: DsButtonSize.compact,
                  tooltip: b.stockTotal >= cap ? 'El lago está lleno' : null,
                  onPressed: b.stockTotal < cap
                      ? () => c.stockFish(f.id, b.id)
                      : null),
            ),
          SizedBox(height: DsSpace.xs),
          Align(
              alignment: Alignment.centerLeft,
              child: DsButton('VOLVER',
                  key: const ValueKey('town-edit-back'),
                  size: DsButtonSize.compact,
                  onPressed: () => c.editStep(TownEditStep.options))),
        ]);
      case TownEditStep.confirmDelete:
        if (b == null) return null;
        final lake = b.kind == BuildKind.lago;
        final n = lake ? b.stockTotal : TownRules.seedsBack(b);
        return col([
          DsSectionHeader(lake ? 'BORRAR LAGO' : 'BORRAR HUERTA'),
          Text(
              lake
                  ? (n > 0
                      ? 'Se pierden los $n peces soltados en este lago.'
                      : 'El lago no tiene peces soltados.')
                  : (n > 0
                      ? 'Se pierden los cultivos; te vuelven $n semillas, '
                          'una por parcela plantada.'
                      : 'La huerta no tiene nada plantado.'),
              key: const ValueKey('town-edit-delete-warn'),
              style: DsText.detail()),
          SizedBox(height: DsSpace.xs),
          Row(children: [
            DsButton('BORRAR',
                key: const ValueKey('town-edit-delete-ok'),
                size: DsButtonSize.compact,
                kind: DsButtonKind.primary,
                onPressed: c.editRemove),
            SizedBox(width: DsSpace.xs),
            cancel(),
          ]),
        ]);
      case TownEditStep.moving || TownEditStep.placing:
        return col([
          DsSectionHeader(e.step == TownEditStep.moving
              ? 'MOVER'
              : construction(e.placeDef ?? '')?.name ?? ''),
          Text(c.editGhostError ?? 'Clic en el mapa para dejarlo.',
              key: const ValueKey('town-edit-ghost'), style: DsText.detail()),
          if (e.step == TownEditStep.moving &&
              c.editSelected?.kind == BuildKind.lago)
            Text('Pegado a otro lago, se funden en uno con todos sus peces.',
                style: DsText.detail()),
          SizedBox(height: DsSpace.xs),
          Align(alignment: Alignment.centerLeft, child: cancel()),
        ]);
    }
  }
}
