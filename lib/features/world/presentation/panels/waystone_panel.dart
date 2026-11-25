import 'package:material_ui/material_ui.dart';

import '../../../../game_engine/data/biomes_catalog.dart';
import '../../../../game_engine/models/game_map.dart';
import '../hud/full_map.dart';
import '../hud/world_hud.dart' show minimapLootFor, overworldOverlayFor;
import '../session_controller.dart';
import '../session_view.dart';
import '../world_strings.dart';

/// PIEDRAS DE PASO (docs/specs/biome_regions.md § 4): the big map of the
/// region in pick mode — the same [FullMap] the dungeon waystones use —
/// with every waystone marked (activated ones lit, the rest grey "not
/// found yet"). Hover names a stone; clicking another activated stone
/// travels there right away (the one you stand at does nothing). Purely
/// visual: the controller validates and sends the travel.
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
    final ow = overworldOverlayFor(view, c);
    // Only the activated stones and those in discovered ground
    // (biome_exploration.md § 11.4); the rest stay hidden in the fog.
    final all = [
      if (lay != null)
        for (final p in stones(lay))
          if (c.waystoneActive(p.id) ||
              ow == null ||
              ow.knownTile(p.tx, p.ty))
            p
    ];
    final active = {
      for (final p in all)
        if (c.waystoneActive(p.id)) p.id
    };
    String label(MapPoi p) => active.contains(p.id) && lay != null
        ? name(context, lay, p.id)
        : context.t('ui.world.way.unknown');

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
      overworld: ow,
      waystones: [for (final p in all) (p, active.contains(p.id))],
      destinations: [
        for (final p in all)
          if (active.contains(p.id) && p.id != here) p
      ],
      originId: here,
      onTravel: c.travelWaystone,
      pick: FullMapPick(label: label),
      onClose: c.closePanel,
    );
  }
}
