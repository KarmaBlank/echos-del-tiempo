import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/design/ds_layout_host.dart';
import '../../../../app/theme/panel_frame.dart';
import '../../../../core/layout/layout_doc.dart';
import '../../../../core/layout/layout_spec.dart';
import '../../../../game_engine/data/classes_catalog.dart';
import '../../../../game_engine/data/passive_tree_catalog.dart';
import '../../../../game_engine/models/attributes.dart';
import '../../../../game_engine/models/item.dart';
import '../../../../game_engine/models/loot.dart';
import '../../../../game_engine/models/player_profile.dart';
import '../../../../game_engine/rules/inventory_rules.dart';
import '../../../../game_engine/rules/passive_tree_rules.dart';
import '../../../../game_engine/rules/progression_rules.dart';
import '../../../../game_engine/rules/stats_calculator.dart';
import '../../../../game_engine/models/profile_store.dart';
import '../../../../game_engine/rules/battle_engine.dart';
import '../../../../game_engine/rules/session_engine.dart';
import '../../../characters/domain/stash.dart';
import '../../../inventory/presentation/inventory_layout.dart';
import '../../../inventory/presentation/inventory_tab.dart';
import '../../../inventory/presentation/shop_sections.dart';
import '../../../world/presentation/session_controller.dart';
import '../../../world/presentation/session_view.dart';
import '../../../characters/presentation/stash_board.dart';
import '../../../characters/presentation/stash_layout.dart';

/// Una pantalla en la galería de Editor → LAYOUT (editor_layout.md § 3):
/// su spec y cómo dibujarla con **datos de ejemplo**, sin red ni
/// Firestore. `build == null`: "sin vista previa" (deuda de migración).
class LayoutPreview {
  const LayoutPreview(this.screen, this.title, {this.spec, this.build});
  final String screen;
  final String title;
  final LayoutScreenSpec? spec;
  final Widget Function(LayoutDoc doc, DsLayoutHooks? hooks)? build;

  bool get migrated => spec != null && build != null;
}

/// Todas las pantallas (§ 2.1). Las migradas tienen spec y vista previa;
/// el resto aparece para ver qué falta.
List<LayoutPreview> layoutPreviews() => [
      LayoutPreview(StashLayout.screen, 'ALIJO',
          spec: StashLayout.spec, build: _stash),
      LayoutPreview(InventoryTabLayout.screen, 'INVENTARIO',
          spec: InventoryTabLayout.spec, build: _inventory),
      const LayoutPreview('craft.fuse', 'FUSIÓN'),
      const LayoutPreview('craft.forge', 'FORJA'),
      const LayoutPreview('craft.condense', 'CONDENSAR'),
      const LayoutPreview('character', 'PERSONAJE'),
      const LayoutPreview('shop', 'TIENDA'),
      const LayoutPreview('achievements', 'HAZAÑAS'),
      const LayoutPreview('settings', 'AJUSTES'),
      const LayoutPreview('build', 'BUILD'),
      const LayoutPreview('title', 'TÍTULO'),
      const LayoutPreview('lobby', 'SALA'),
      const LayoutPreview('world_hud', 'HUD DEL MAPA'),
      const LayoutPreview('battle', 'BATALLA'),
    ];

// ------------------------------------------------------------ ALIJO

/// Reglas del juego para las vistas previas (motor puro, sin red).
final ProgressionRules sampleRules = ProgressionRules(
    stats: StatsCalculator(
        classes: kClasses, treeRules: PassiveTreeRules(kPassiveTree)));

/// Personaje de ejemplo: guerrero Nv 5 con armas, pociones y materiales.
PlayerProfile sampleProfile() {
  var p = sampleRules.normalize(PlayerProfile(
    name: 'Ana',
    classId: 'guerrero',
    level: 5,
    credits: 5000,
    points: 2,
    attributes: const PlayerAttributes({
      Attribute.vit: 10,
      Attribute.esp: 4,
      Attribute.agi: 6,
      Attribute.fue: 15,
      Attribute.des: 9,
    }),
    items: const [
      ItemInstance(uid: 'espada_bronce', baseId: 'espada_bronce'),
      ItemInstance(
          uid: 'e1',
          baseId: 'espada_ignea',
          rarity: Rarity.epico,
          itemLevel: 10,
          name: 'Filo del Alba',
          affixes: [AffixRoll('feroz', 5, 7), AffixRoll('certero', 5, 3)]),
      ItemInstance(
          uid: 'r1',
          baseId: 'hacha_rompe',
          rarity: Rarity.raro,
          itemLevel: 10,
          name: 'Eco Voraz',
          affixes: [AffixRoll('feroz', 5, 6)]),
      ItemInstance(uid: 'c1', baseId: 'baculo_fuego', itemLevel: 2),
    ],
    equipped: 'espada_bronce',
  ));
  for (final k in StackKind.values) {
    p = InventoryRules.withStack(p, k, 3);
  }
  return p;
}

class _SampleStashHost implements StashBoardHost {
  _SampleStashHost()
      : profile = sampleProfile(),
        stash = Stash.empty().put(
            0,
            const StashEntry.item(ItemInstance(
                uid: 's1',
                baseId: 'katana_escarcha',
                rarity: Rarity.magico,
                itemLevel: 5)));
  @override
  ProgressionRules get rules => sampleRules;
  @override
  final PlayerProfile profile;
  @override
  final Stash stash;
  @override
  bool get busy => false;
  @override
  String? get notice => null;
  @override
  String? put(List<String> tokens, int tab) => null;
  @override
  String? take(List<int> cells) => null;
  @override
  bool moveStash(int from, int to) => false;
  @override
  bool moveCharacter(int from, int to) => false;
  @override
  void achievement(String id) {}
}

final _stashHost = _SampleStashHost();

Widget _stash(LayoutDoc doc, DsLayoutHooks? hooks) => PanelFrame(
      title: 'ALIJO',
      width: 1000,
      onClose: () {},
      actions: [PanelButton('CERRAR', onPressed: () {})],
      child: StashBoard(
          host: _stashHost,
          title: 'Ana · Guerrero · Nv 5',
          layout: doc,
          layoutHooks: hooks),
    );

// ------------------------------------------------------- INVENTARIO

/// Sesión local de ejemplo (motor puro, perfil en memoria, sin reloj ni
/// red): una sola para todas las vistas previas que la necesitan.
SessionController? _sampleSession;
SessionController sampleSession() => _sampleSession ??= SessionController(
      engine: SessionEngine(
          battles: BattleEngine(stats: sampleRules.stats),
          progression: sampleRules,
          achievementsEnabled: false),
      store: InMemoryProfileStore(sampleProfile()),
      clock: const SessionClock(autoStart: false),
    )..start();

/// Dibuja [build] con la vista de la sesión de ejemplo (vacío mientras
/// carga). Solo se reconstruye cuando cambia la sesión.
class _SessionPreview extends StatefulWidget {
  const _SessionPreview(this.build);
  final Widget Function(SessionView view, SessionController c) build;
  @override
  State<_SessionPreview> createState() => _SessionPreviewState();
}

class _SessionPreviewState extends State<_SessionPreview> {
  final _c = sampleSession();
  SessionView? _view;
  void Function()? _off;

  @override
  void initState() {
    super.initState();
    _off = _c.addListener((v) {
      if (mounted) setState(() => _view = v);
    });
  }

  @override
  void dispose() {
    _off?.call();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final v = _view;
    if (v == null) return const SizedBox(height: 200);
    final child = widget.build(v, _c);
    // Dentro de la app ya hay ProviderScope; el Editor suelto (tests)
    // usa uno propio con el motor de ejemplo.
    try {
      ProviderScope.containerOf(context, listen: false);
      return child;
    } catch (_) {
      return ProviderScope(overrides: [
        sessionEngineProvider.overrideWithValue(_c.engine),
      ], child: child);
    }
  }
}

Widget _inventory(LayoutDoc doc, DsLayoutHooks? hooks) => PanelFrame(
      title: 'PERSONAJE · INVENTARIO',
      width: 1000,
      onClose: () {},
      child: SizedBox(
        height: 560,
        child: _SessionPreview((v, c) => InventoryTab(
            shop: ShopContext(v, c), layout: doc, layoutHooks: hooks)),
      ),
    );
