import 'package:material_ui/material_ui.dart';

import '../../../../app/design/design.dart';
import '../../../../game_engine/data/biomes_catalog.dart';
import '../../../../game_engine/models/game_map.dart';
import '../hud/full_map.dart';
import '../hud/world_hud.dart' show minimapLootFor;
import '../session_controller.dart';
import '../session_view.dart';
import '../world_strings.dart';

/// PIEDRAS DE PASO (docs/specs/biome_regions.md § 4): the big map of the
/// region in pick mode — the same [FullMap] the dungeon waystones use —
/// with every waystone marked (activated ones lit, the rest grey "not
/// found yet"). Hover names a stone, click selects it and the detail on
/// the right has TRAVEL. Purely visual: the controller validates and
/// sends the travel.
class WaystonePanel extends StatelessWidget {
  const WaystonePanel(
      {super.key, required this.view, required this.controller});

  final SessionView view;
  final SessionController controller;

  /// The waystones of [lay] as map points (id = index in the layout).
  static List<MapPoi> stones(BiomeLayout lay) => [
        for (var i = 0; i < lay.waystones.length; i++)
          MapPoi(
              id: i,
              kind: PoiKind.waystone,
              tx: lay.waystones[i].x,
              ty: lay.waystones[i].y),
      ];

  static String name(BuildContext context, BiomeLayout lay, int i) {
    final w = lay.waystones[i];
    return switch (w.site) {
      WaystoneSite.entrance => context.t('ui.world.way.site_entrance'),
      WaystoneSite.lake =>
        context.t('ui.world.way.site_lake', {'name': lay.lakes[w.ref].name}),
      WaystoneSite.mine =>
        context.t('ui.world.way.site_mine', {'n': w.ref + 1}),
      WaystoneSite.section =>
        context.t('ui.world.way.site_section', {'n': w.ref + 1}),
      WaystoneSite.shrine =>
        context.t('ui.world.way.site_shrine', {'n': w.ref + 1}),
      WaystoneSite.cavern =>
        context.t('ui.world.way.site_cavern', {'n': w.ref + 1}),
    };
  }

  @override
  Widget build(BuildContext context) {
    final c = controller;
    final lay = biomeLayout(c.place);
    final here = c.nearWaystone;
    final all = lay == null ? const <MapPoi>[] : stones(lay);
    final active = {
      for (final p in all)
        if (c.waystoneActive(p.id)) p.id
    };
    String label(MapPoi p) => active.contains(p.id) && lay != null
        ? name(context, lay, p.id)
        : context.t('ui.world.way.unknown');

    Widget detail(MapPoi p) {
      final on = active.contains(p.id);
      final canGo = on && here != null && here != p.id;
      return DsDetailPane(
        key: const ValueKey('way-detail'),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label(p), softWrap: true, style: DsText.title()),
            SizedBox(height: DsSpace.sm),
            if (p.id == here)
              DsBadge(context.t('ui.world.way.here'),
                  key: const ValueKey('way-here')),
            if (!on)
              Text(context.t('ui.world.way.unknown_tip'),
                  softWrap: true, style: DsText.detail())
            else if (p.id != here)
              Text(context.t('ui.world.way.help'),
                  softWrap: true, style: DsText.detail()),
          ],
        ),
        actions: DsButton(context.t('ui.world.way.go'),
            key: ValueKey('way-go-${p.id}'),
            kind: DsButtonKind.primary,
            onPressed: canGo ? () => c.travelWaystone(p.id) : null),
      );
    }

    return FullMap(
      key: const ValueKey('panel-waystone'),
      title: context.t('ui.world.way.title'),
      map: view.map,
      session: view.session,
      localId: view.localId,
      localX: c.local.x,
      localY: c.local.y,
      time: view.session.time,
      loot: minimapLootFor(view, c),
      waystones: [for (final p in all) (p, active.contains(p.id))],
      destinations: [
        for (final p in all)
          if (active.contains(p.id) && p.id != here) p
      ],
      originId: here,
      onTravel: c.travelWaystone,
      pick: FullMapPick(label: label, detail: detail, initial: here),
      onClose: c.closePanel,
    );
  }
}
