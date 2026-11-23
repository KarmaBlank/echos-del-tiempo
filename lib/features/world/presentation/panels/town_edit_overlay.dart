import 'package:material_ui/material_ui.dart';

import '../../../../app/design/design.dart';
import '../../../../game_engine/data/construction_catalog.dart';
import '../../../../game_engine/data/fishing_catalog.dart';
import '../../../../game_engine/models/world_save.dart';
import '../../../../game_engine/rules/town_plan.dart';
import '../../../../game_engine/rules/town_rules.dart';
import '../session_controller.dart';
import 'fishing_widgets.dart' show fishRarityColor;
import 'life_icon.dart';
import 'life_item_grid.dart';

/// Interfaz de la edición del pueblo (town_editor.md § 1): barra de
/// arriba con LISTO, y a la derecha el menú del paso en curso (ampliar,
/// qué construir, opciones de un lago o una huerta, soltar peces,
/// confirmar el borrado). El mapa (cámara, fantasmas) lo dibuja
/// `TownEditLayer`.
class TownEditOverlay extends StatelessWidget {
  const TownEditOverlay({super.key, required this.controller});

  final SessionController controller;

  /// Alto reservado para la barra de arriba (las tarjetas de las franjas
  /// van debajo).
  static const barHeight = 56.0;

  /// Ancho de la columna de la derecha para una pantalla de [w] px.
  static double sideWidth(double w) => (w * 0.3).clamp(240.0, 320.0);

  /// Hay algo en la columna de la derecha (menú o info).
  static bool sideOpen(SessionController c) {
    final e = c.townEdit;
    return e != null &&
        (e.step != TownEditStep.browse || e.hoverBuild != null);
  }

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
      final side = sideWidth(box.maxWidth);
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          key: const ValueKey('town-edit-bar'),
          color: DsColors.background,
          padding: EdgeInsets.symmetric(
              horizontal: DsSpace.md, vertical: DsSpace.xs),
          child: Row(children: [
            Text(
                switch (e.hire) {
                  BuildKind.huerta => 'CONTRATAR GRANJERO',
                  BuildKind.lago => 'CONTRATAR PESCADOR',
                  _ => 'EDICIÓN DEL PUEBLO',
                },
                style: DsText.title()),
            SizedBox(width: DsSpace.md),
            Expanded(
                child: Text(_hint(c, e),
                    key: const ValueKey('town-edit-hint'),
                    maxLines: 2,
                    softWrap: true,
                    style: DsText.subtitle())),
            SizedBox(width: DsSpace.md),
            DsButton(e.hire == null ? 'LISTO [ESC]' : 'CANCELAR [ESC]',
                key: ValueKey(
                    e.hire == null ? 'town-edit-done' : 'town-hire-cancel'),
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

  /// Info de la construcción bajo el mouse (las franjas muestran su
  /// costo en su tarjeta). `null` si no hay nada o si ya hay un menú.
  static Widget? _info(SessionController c, TownEdit e) {
    final town = c.town;
    if (e.step != TownEditStep.browse) return null;
    final b = town.builds.where((b) => b.id == e.hoverBuild).firstOrNull;
    if (e.hire case final kind?) {
      if (b == null || b.kind != kind) return null;
      final why = c.hireWhy(b);
      return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            DsSectionHeader(b.kind.label),
            Text(TownRules.helperLine(b), style: DsText.detail()),
            Text(why ?? '${TownRules.helperCost} de oro. Clic para contratar.',
                key: const ValueKey('town-hire-info'),
                style: DsText.detail(why == null ? null : DsColors.textDisabled)),
          ]);
    }
    if (b == null) {
      final l = TownPlan.landmarksOf(town)
          .where((l) => l.id == e.hoverBuild)
          .firstOrNull;
      if (l == null) return null;
      return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            DsSectionHeader(l.name),
            Text(_landmarkText, style: DsText.detail()),
            Text('Clic para moverlo.', style: DsText.detail()),
          ]);
    }
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

  static const _landmarkText =
      'Lugar fijo del pueblo: se puede mover, no borrar. Los caminos se '
      'rearman solos hasta la fuente.';

  static String _hint(SessionController c, TownEdit e) => switch (e.step) {
        _ when e.hire == BuildKind.huerta =>
          'Elegí una huerta para contratar un granjero',
        _ when e.hire == BuildKind.lago => '¿En qué lago querés el pescador?',
        TownEditStep.moving ||
        TownEditStep.placing =>
          c.editGhostError ?? 'Clic para dejarlo acá',
        _ => 'WASD/arrastrar: mover · rueda: zoom · clic: elegir',
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
          DsSectionHeader('AMPLIAR AL ${side.label}'),
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
        if (c.editLandmark case final l? when b == null) {
          return col([
            DsSectionHeader(l.name),
            Text(_landmarkText,
                key: const ValueKey('town-edit-info'), style: DsText.detail()),
            SizedBox(height: DsSpace.xs),
            Wrap(spacing: DsSpace.xs, runSpacing: DsSpace.xs, children: [
              DsButton('MOVER',
                  key: const ValueKey('town-edit-move'),
                  size: DsButtonSize.compact,
                  onPressed: c.editStartMove),
              cancel(),
            ]),
          ]);
        }
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
          // Ayudantes (farming.md § 8): uno por área, tope por tamaño.
          DsSectionHeader(lake ? 'PESCADORES' : 'GRANJEROS',
              trailing: DsBadge('${b.helper} / ${TownRules.helperCap(b)}',
                  key: const ValueKey('town-edit-helpers'))),
          Text(TownRules.helperLine(b), style: DsText.detail()),
          Builder(builder: (_) {
            final p = c.view?.me?.profile;
            final why = p == null
                ? 'Sin personaje'
                : TownRules.cannotHire(p, town, b.id);
            return Wrap(spacing: DsSpace.xs, runSpacing: DsSpace.xs, children: [
              DsButton('CONTRATAR AYUDANTE',
                  key: const ValueKey('town-edit-hire'),
                  size: DsButtonSize.compact,
                  kind: DsButtonKind.primary,
                  tooltip: why ?? '${TownRules.helperCost} de oro',
                  onPressed: why == null ? () => c.hireHelper(b.id) : null),
              DsButton('DESPEDIR',
                  key: const ValueKey('town-edit-fire'),
                  size: DsButtonSize.compact,
                  onPressed: b.helper > 0 ? () => c.fireHelper(b.id) : null),
            ]);
          }),
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
          if (b.stock.isNotEmpty)
            Wrap(spacing: DsSpace.xs, runSpacing: DsSpace.xs, children: [
              for (final en in b.stock.entries)
                if (kFish[en.key] case final f?)
                  DsTag('${f.name} ×${en.value}${en.value >= 2 ? ' · cría' : ''}',
                      color: fishRarityColor(f.rarity)),
            ]),
          SizedBox(height: DsSpace.xs),
          // Grilla (como el inventario): elegir el pez, detalle y SOLTAR.
          SizedBox(
            height: 320,
            child: LifeItemGrid(
              key: const ValueKey('town-edit-release-grid'),
              groups: [
                LifeItemGroup(null, [
                  for (final f in fish)
                    LifeItemCellData(
                      id: 'town-edit-release-${f.id}',
                      icon: LifeIcon(f.id, LifeIconKind.pescado,
                          size: LifeItemGrid.iconSize),
                      border: fishRarityColor(f.rarity),
                      search: f.name,
                      count: p?.life.count(f.id) ?? 0,
                      detail: LifeItemDetail(
                        name: f.name,
                        nameColor: fishRarityColor(f.rarity),
                        tags: [(f.rarity.label.toUpperCase(), fishRarityColor(f.rarity))],
                        lines: ['Tenés ${p?.life.count(f.id) ?? 0}',
                          'En este lago: ${b.stock[f.id] ?? 0}'],
                        actions: [
                          DsButton('SOLTAR EN EL LAGO',
                              key: ValueKey('town-edit-release-btn-${f.id}'),
                              size: DsButtonSize.compact,
                              tooltip: b.stockTotal >= cap ? 'El lago está lleno' : null,
                              onPressed: b.stockTotal < cap
                                  ? () => c.stockFish(f.id, b.id)
                                  : null),
                        ],
                      ),
                    ),
                ]),
              ],
              empty: 'No tenés peces en la bolsa.',
            ),
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
