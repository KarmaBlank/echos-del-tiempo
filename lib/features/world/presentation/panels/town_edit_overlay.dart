import '../../../inventory/domain/item_names.dart';
import '../../domain/town_names.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/design/design.dart';
import '../../../../game_engine/data/biomes_catalog.dart';
import '../../../../game_engine/data/fishing_catalog.dart';
import '../../../../game_engine/models/world_save.dart';
import '../../../../game_engine/rules/town_plan.dart';
import '../../../../game_engine/rules/helper_rules.dart';
import '../../../../game_engine/models/session_action.dart' show TownOp;
import '../../../../game_engine/rules/resident_rules.dart';
import '../../../../game_engine/rules/town_rules.dart';
import '../session_controller.dart';
import 'fishing_widgets.dart' show fishRarityColor;
import 'life_icon.dart';
import 'life_item_grid.dart';
import 'town_build_palette.dart';
import '../world_strings.dart';

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
    // La ventana CONSTRUIR va centrada y el botón del borde es chico:
    // mirando o poniendo, el mapa queda libre salvo el panel de info.
    if (e == null) return false;
    return switch (e.step) {
      TownEditStep.browse => e.hoverBuild != null,
      TownEditStep.placing => false,
      _ => true,
    };
  }

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final e = c.townEdit;
    if (e == null) return const SizedBox.shrink();
    final s = worldStrings(context);
    final menu = _menu(s, c, e);
    final info = _info(s, c, e);
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
                switch (e.pick) {
                  BuildKind.casa => s.t('ui.town.edit.house_pick_title'),
                  BuildKind.huerta => s.t('ui.town.edit.hire_farmer'),
                  BuildKind.lago => s.t('ui.town.edit.hire_fisher'),
                  BuildKind.gallinero => s.t('ui.town.edit.hire_rancher'),
                  _ => s.t('ui.town.edit.title'),
                },
                style: DsText.title()),
            SizedBox(width: DsSpace.md),
            Expanded(
                child: Text(_hint(s, c, e),
                    key: const ValueKey('town-edit-hint'),
                    maxLines: 2,
                    softWrap: true,
                    style: DsText.subtitle())),
            SizedBox(width: DsSpace.md),
            DsButton(e.pick == null ? s.t('ui.town.edit.done') : s.t('ui.town.edit.cancel_esc'),
                key: ValueKey(
                    e.pick == null ? 'town-edit-done' : 'town-hire-cancel'),
                size: DsButtonSize.compact,
                kind: DsButtonKind.primary,
                onPressed: c.exitTownEdit),
          ]),
        ),
        Expanded(
          child: Stack(children: [
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: EdgeInsets.all(DsSpace.sm),
                child: SizedBox(
                  width: side,
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Botón fijo arriba: lo de abajo (menú, info)
                        // nunca lo corre ni lo tapa.
                        if (e.buildAvailable && !e.buildOpen) ...[
                          Align(
                            alignment: Alignment.centerRight,
                            child: DsButton(
                                switch (c.townEdit?.placeDef) {
                                  final id? when
                                      e.step == TownEditStep.placing =>
                                    s.t('ui.town.edit.build_toggle_piece', {
                                      'name': TownBuildPalette.pieces(s, c)
                                              .where((p) => p.id == id)
                                              .firstOrNull
                                              ?.name ??
                                          id
                                    }),
                                  _ => s.t('ui.town.edit.build_toggle'),
                                },
                                key: const ValueKey('town-build-toggle'),
                                size: DsButtonSize.compact,
                                kind: DsButtonKind.primary,
                                onPressed: () => c.setBuildOpen(true)),
                          ),
                          if (menu != null || info != null)
                            SizedBox(height: DsSpace.xs),
                        ],
                        Flexible(
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
                      ]),
                ),
              ),
            ),
            // Ventana CONSTRUIR centrada (town_editor.md § 1.2): un clic
            // afuera o Esc la cierra.
            if (e.buildShown) ...[
              Positioned.fill(
                child: GestureDetector(
                  key: const ValueKey('town-build-barrier'),
                  behavior: HitTestBehavior.opaque,
                  onTap: () => c.setBuildOpen(false),
                  child: ColoredBox(
                      color: DsColors.background.withValues(alpha: 0.4)),
                ),
              ),
              Center(
                child: LayoutBuilder(builder: (context, area) {
                  final size = TownBuildPalette.windowSize(
                      Size(area.maxWidth, area.maxHeight));
                  return Container(
                    key: const ValueKey('town-build-window'),
                    width: size.width,
                    height: size.height,
                    decoration: BoxDecoration(
                      color: DsColors.background,
                      border: Border.all(color: DsColors.border, width: 2),
                    ),
                    padding: EdgeInsets.all(DsSpace.md),
                    child: TownBuildPalette(
                        controller: c,
                        onClose: () => c.setBuildOpen(false)),
                  );
                }),
              ),
            ],
          ]),
        ),
      ]);
    });
  }

  /// Info de la construcción bajo el mouse (las franjas muestran su
  /// costo en su tarjeta). `null` si no hay nada o si ya hay un menú.
  static Widget? _info(Strings s, SessionController c, TownEdit e) {
    final town = c.town;
    if (e.step != TownEditStep.browse) return null;
    final b = town.builds.where((b) => b.id == e.hoverBuild).firstOrNull;
    if (e.houseFor != null) {
      if (e.selected != null || b == null || b.kind != BuildKind.casa) {
        return null;
      }
      final why = c.pickWhy(b);
      return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            DsSectionHeader(s.t('ui.town.edit.house_title', {'level': b.level})),
            Text(why ?? s.t('ui.town.edit.house_free'),
                key: const ValueKey('town-house-info'),
                style: DsText.detail(why == null ? null : DsColors.textDisabled)),
          ]);
    }
    if (e.hire case final kind?) {
      if (b == null || !SessionController.hireKindMatches(kind, b.kind)) return null;
      final why = c.hireWhy(b);
      return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            DsSectionHeader(b.kind.text),
            Text(TownRules.helperLine(b), style: DsText.detail()),
            Text(
                why ??
                    s.t('ui.town.edit.hire_info', {
                      'cost': HelperRules.costText(HelperRules.hireCost(b.kind))
                    }),
                key: const ValueKey('town-hire-info'),
                style: DsText.detail(why == null ? null : DsColors.textDisabled)),
          ]);
    }
    if (TownState.parseDecorId(e.hoverBuild) case (final x, final y)?) {
      final id = town.decor.where((d) => d.$2 == x && d.$3 == y).firstOrNull?.$1;
      return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            DsSectionHeader(s.t('ui.town.decor.${id ?? 'fence'}.name')),
            Text(s.t('ui.town.decor.text'), style: DsText.detail()),
            Text(s.t('ui.town.edit.click_options'), style: DsText.detail()),
          ]);
    }
    if (TownState.parseLightId(e.hoverBuild) != null) {
      return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            DsSectionHeader(s.t('ui.town.edit.lamp')),
            Text(s.t('ui.town.edit.lamp_text'), style: DsText.detail()),
            Text(s.t('ui.town.edit.click_options'), style: DsText.detail()),
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
            Text(s.t('ui.town.edit.landmark_text'), style: DsText.detail()),
            Text(s.t('ui.town.edit.click_move'), style: DsText.detail()),
          ]);
    }
    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          DsSectionHeader(b.kind.text),
          Text(
              b.kind == BuildKind.lago
                  ? TownRules.lakeSignText(town, b)
                  : TownRules.farmSignText(b),
              style: DsText.detail()),
          Text(s.t('ui.town.edit.click_options'), style: DsText.detail()),
        ]);
  }

  static String _hint(Strings s, SessionController c, TownEdit e) =>
      switch (e.step) {
        _ when e.houseFor != null => s.t('ui.town.edit.hint_house',
            {'name': biomeNpc(e.houseFor!)?.name ?? e.houseFor!}),
        _ when e.hire == BuildKind.huerta =>
          s.t('ui.town.edit.hint_hire_farmer'),
        _ when e.hire == BuildKind.lago => s.t('ui.town.edit.hint_hire_fisher'),
        _ when e.hire?.ranch ?? false =>
          s.t('ui.town.edit.hint_hire_rancher'),
        TownEditStep.moving ||
        TownEditStep.placing =>
          c.editGhostError ?? s.t('ui.town.edit.hint_place'),
        _ => s.t('ui.town.edit.hint_browse'),
      };

  Widget? _menu(Strings s, SessionController c, TownEdit e) {
    final town = c.town;
    final b = c.editSelected;
    Widget cancel() => DsButton(s.t('ui.town.edit.cancel'),
        key: const ValueKey('town-edit-cancel'),
        size: DsButtonSize.compact,
        onPressed: c.editBack);
    Widget col(List<Widget> ch) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: ch);
    // Casa elegida para el habitante: confirmar (overworld_biomes.md § 10.1).
    if (e.houseFor case final npc?) {
      if (e.selected == null) return null;
      final name = biomeNpc(npc)?.name ?? npc;
      return col([
        DsSectionHeader(s.t('ui.town.edit.house_pick_title')),
        Text(s.t('ui.town.edit.house_confirm_text', {'name': name}),
            style: DsText.detail()),
        SizedBox(height: DsSpace.xs),
        Row(children: [
          Expanded(
            child: DsButton(s.t('ui.town.edit.house_confirm', {'name': name}),
                key: const ValueKey('town-house-confirm'),
                size: DsButtonSize.compact,
                kind: DsButtonKind.primary,
                onPressed: c.confirmHouse),
          ),
          SizedBox(width: DsSpace.xs),
          cancel(),
        ]),
      ]);
    }
    switch (e.step) {
      case TownEditStep.browse:
        // La paleta va en la ventana CONSTRUIR centrada (§ 1.2).
        return null;
      case TownEditStep.side:
        final side = e.side!;
        final why = c.cannotExpandTown(side);
        return col([
          DsSectionHeader(s.t('ui.town.edit.expand_title', {'side': side.label})),
          Text(
              s.t('ui.town.edit.expand_text', {
                'tiles': kTownStrip,
                'cost': TownRules.costText(TownRules.cost(town.expansions + 1))
              }),
              style: DsText.detail()),
          SizedBox(height: DsSpace.xs),
          Row(children: [
            DsButton(s.t('ui.town.edit.expand'),
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
      case TownEditStep.options:
        final decor = TownState.parseDecorId(e.selected);
        final decorId = decor == null
            ? null
            : town.decor.where((d) => (d.$2, d.$3) == decor).firstOrNull?.$1;
        if (TownState.parseLightId(e.selected) != null || decorId != null) {
          return col([
            DsSectionHeader(decorId != null
                ? s.t('ui.town.decor.$decorId.name')
                : s.t('ui.town.edit.lamp')),
            Text(
                decorId != null
                    ? s.t('ui.town.decor.text')
                    : s.t('ui.town.edit.lamp_text'),
                key: const ValueKey('town-edit-info'), style: DsText.detail()),
            SizedBox(height: DsSpace.xs),
            Wrap(spacing: DsSpace.xs, runSpacing: DsSpace.xs, children: [
              DsButton(s.t('ui.town.edit.move'),
                  key: const ValueKey('town-edit-move'),
                  size: DsButtonSize.compact,
                  onPressed: c.editStartMove),
              DsButton(s.t('ui.town.edit.delete'),
                  key: const ValueKey('town-edit-delete-ok'),
                  size: DsButtonSize.compact,
                  onPressed: c.editRemove),
              cancel(),
            ]),
          ]);
        }
        if (c.editLandmark case final l? when b == null) {
          return col([
            DsSectionHeader(l.name),
            Text(s.t('ui.town.edit.landmark_text'),
                key: const ValueKey('town-edit-info'), style: DsText.detail()),
            SizedBox(height: DsSpace.xs),
            Wrap(spacing: DsSpace.xs, runSpacing: DsSpace.xs, children: [
              DsButton(s.t('ui.town.edit.move'),
                  key: const ValueKey('town-edit-move'),
                  size: DsButtonSize.compact,
                  onPressed: c.editStartMove),
              cancel(),
            ]),
          ]);
        }
        if (b == null) return null;
        if (b.kind == BuildKind.casa) {
          // Casa (town_editor.md § 3.4): a quién se le asigna.
          final living = ResidentRules.living(town);
          return col([
            DsSectionHeader(s.t('ui.town.edit.house_title', {'level': b.level})),
            Text(
                b.resident == null
                    ? s.t('ui.town.edit.house_empty')
                    : s.t('ui.town.edit.house_lives', {'name': biomeNpcName(b.resident!)}),
                key: const ValueKey('town-edit-info'),
                style: DsText.detail()),
            SizedBox(height: DsSpace.xs),
            Wrap(spacing: DsSpace.xs, runSpacing: DsSpace.xs, children: [
              for (final n in living)
                DsButton(s.t('ui.town.edit.assign', {'name': n.name.toUpperCase()}),
                    key: ValueKey('town-edit-assign-${n.id}'),
                    size: DsButtonSize.compact,
                    onPressed: b.resident == n.id
                        ? null
                        : () =>
                            c.residentOp(TownOp.assign, n.id, target: b.id)),
              if (living.isEmpty)
                Text(s.t('ui.town.edit.nobody_lives'),
                    style: DsText.detail()),
            ]),
            SizedBox(height: DsSpace.xs),
            Wrap(spacing: DsSpace.xs, runSpacing: DsSpace.xs, children: [
              DsButton(s.t('ui.town.edit.move'),
                  key: const ValueKey('town-edit-move'),
                  size: DsButtonSize.compact,
                  onPressed: c.editStartMove),
              DsButton(s.t('ui.town.edit.delete'),
                  key: const ValueKey('town-edit-delete'),
                  size: DsButtonSize.compact,
                  onPressed: () => c.editStep(TownEditStep.confirmDelete)),
              cancel(),
            ]),
          ]);
        }
        final lake = b.kind == BuildKind.lago;
        return col([
          DsSectionHeader(b.kind.text),
          Text(
              lake
                  ? TownRules.lakeSignText(town, b)
                  : TownRules.farmSignText(b),
              key: const ValueKey('town-edit-info'),
              style: DsText.detail()),
          SizedBox(height: DsSpace.xs),
          // Ayudantes (farming.md § 8): uno por área, tope por tamaño.
          DsSectionHeader(lake ? s.t('ui.town.edit.fishers') : s.t('ui.town.edit.farmers'),
              trailing: DsBadge(s.t('ui.town.edit.count_of', {'n': b.helper, 'max': TownRules.helperCap(b)}),
                  key: const ValueKey('town-edit-helpers'))),
          Text(TownRules.helperLine(b), style: DsText.detail()),
          Builder(builder: (_) {
            final p = c.view?.me?.profile;
            final why = p == null
                ? s.t('ui.town.edit.no_character')
                : TownRules.cannotHire(p, town, b.id);
            return Wrap(spacing: DsSpace.xs, runSpacing: DsSpace.xs, children: [
              DsButton(s.t('ui.town.edit.hire_helper'),
                  key: const ValueKey('town-edit-hire'),
                  size: DsButtonSize.compact,
                  kind: DsButtonKind.primary,
                  tooltip: why ??
                      HelperRules.costText(HelperRules.hireCost(b.kind)),
                  onPressed: why == null ? () => c.hireHelper(b.id) : null),
              DsButton(s.t('ui.town.edit.fire'),
                  key: const ValueKey('town-edit-fire'),
                  size: DsButtonSize.compact,
                  onPressed: b.helper > 0 ? () => c.fireHelper(b.id) : null),
            ]);
          }),
          SizedBox(height: DsSpace.xs),
          Wrap(spacing: DsSpace.xs, runSpacing: DsSpace.xs, children: [
            if (lake)
              DsButton(s.t('ui.town.edit.add_species'),
                  key: const ValueKey('town-edit-stock'),
                  size: DsButtonSize.compact,
                  onPressed: () => c.editStep(TownEditStep.stocking)),
            DsButton(s.t('ui.town.edit.move'),
                key: const ValueKey('town-edit-move'),
                size: DsButtonSize.compact,
                onPressed: c.editStartMove),
            DsButton(lake ? s.t('ui.town.edit.delete_lake') : s.t('ui.town.edit.delete'),
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
          DsSectionHeader(s.t('ui.town.edit.add_species'),
              trailing: DsBadge('${b.stockTotal}/$cap',
                  key: const ValueKey('town-edit-lake-count'))),
          Text(
              s.t('ui.town.edit.stock_text'),
              style: DsText.detail()),
          SizedBox(height: DsSpace.xs),
          // Plantilla TRASPASO: tu bolsa a la izquierda, el lago a la derecha.
          DsTransferTemplate(
            key: const ValueKey('town-edit-release-grid'),
            keyPrefix: 'town-edit-release',
            leftTitle: s.t('ui.town.edit.your_bag'),
            rightTitle: s.t('ui.town.edit.in_lake'),
            left: [
              for (final f in fish)
                DsTransferItem(
                  id: f.id,
                  icon: LifeIcon(f.id, LifeIconKind.pescado,
                      size: LifeItemGrid.iconSize),
                  name: f.text,
                  border: fishRarityColor(f.rarity),
                  count: p?.life.count(f.id) ?? 0,
                  tag: f.rarity.name,
                  info: s.t('ui.town.edit.fish_info',
                      {'rarity': f.rarity.label, 'n': b.stock[f.id] ?? 0}),
                ),
            ],
            right: [
              for (final en in b.stock.entries)
                if (kFish[en.key] case final f?)
                  DsTransferItem(
                    id: f.id,
                    icon: LifeIcon(f.id, LifeIconKind.pescado,
                        size: LifeItemGrid.iconSize),
                    name: f.text,
                    border: fishRarityColor(f.rarity),
                    count: en.value,
                    tag: f.rarity.name,
                    info: en.value >= 2 ? s.t('ui.town.edit.breeds') : s.t('ui.town.edit.release_more'),
                  ),
            ],
            filters: [
              DsTransferFilter(s.t('ui.town.edit.all'), null),
              for (final r in FishRarity.values)
                DsTransferFilter(r.label.toUpperCase(), r.name),
            ],
            searchHint: s.t('ui.town.edit.search_fish'),
            quantities: const [1],
            allowRightToLeft: false,
            leftEmpty: s.t('ui.town.edit.bag_empty'),
            rightEmpty: s.t('ui.town.edit.lake_empty'),
            canMove: (_, id) =>
                b.stockTotal >= cap ? s.t('ui.town.edit.lake_full') : null,
            onMove: (_, id, n) => c.stockFish(id, b.id),
          ),
          SizedBox(height: DsSpace.xs),
          Align(
              alignment: Alignment.centerLeft,
              child: DsButton(s.t('ui.town.edit.back'),
                  key: const ValueKey('town-edit-back'),
                  size: DsButtonSize.compact,
                  onPressed: () => c.editStep(TownEditStep.options))),
        ]);
      case TownEditStep.confirmDelete:
        if (b == null) return null;
        final lake = b.kind == BuildKind.lago;
        final n = lake ? b.stockTotal : TownRules.seedsBack(b);
        return col([
          DsSectionHeader(b.kind == BuildKind.casa
              ? s.t('ui.town.edit.delete_house')
              : lake
                  ? s.t('ui.town.edit.delete_lake')
                  : s.t('ui.town.edit.delete_farm')),
          Text(
              b.kind == BuildKind.casa
                  ? s.t('ui.town.edit.delete_house_warn')
                  : lake
                      ? s.t('ui.town.edit.delete_lake_warn', {'n': n})
                      : s.t('ui.town.edit.delete_farm_warn', {'n': n}),
              key: const ValueKey('town-edit-delete-warn'),
              style: DsText.detail()),
          SizedBox(height: DsSpace.xs),
          Row(children: [
            DsButton(s.t('ui.town.edit.delete'),
                key: const ValueKey('town-edit-delete-ok'),
                size: DsButtonSize.compact,
                kind: DsButtonKind.primary,
                onPressed: c.editRemove),
            SizedBox(width: DsSpace.xs),
            cancel(),
          ]),
        ]);
      case TownEditStep.placing:
        // Poniendo: el mapa queda libre; la ayuda va en la barra y el
        // botón CONSTRUIR del borde muestra la pieza (§ 1.2).
        return null;
      case TownEditStep.moving:
        return col([
          DsSectionHeader(s.t('ui.town.edit.move')),
          Text(c.editGhostError ?? s.t('ui.town.edit.click_map_place'),
              key: const ValueKey('town-edit-ghost'), style: DsText.detail()),
          if (c.editSelected?.kind == BuildKind.lago)
            Text(s.t('ui.town.edit.lake_merge'),
                style: DsText.detail()),
          SizedBox(height: DsSpace.xs),
          Align(alignment: Alignment.centerLeft, child: cancel()),
        ]);
    }
  }
}
