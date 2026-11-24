import 'package:material_ui/material_ui.dart';

import '../../../app/design/design.dart';
import '../../../core/i18n/game_text.dart';
import 'admin_controller.dart';
import 'balance_page.dart';
import 'changes_page.dart';
import 'editor/animations_page.dart';
import 'editor/fx_editor_controller.dart';
import 'editor/layout_editor_controller.dart';
import 'editor/layout_page.dart';
import 'editor/climate_editor_controller.dart';
import 'editor/climate_page.dart';
import 'editor/npc_editor_controller.dart';
import 'editor/npcs_page.dart';
import 'editor/npc_variants_controller.dart';
import 'editor/npc_variants_page.dart';
import '../../combat/domain/sprite_entry.dart' show NpcVariantsOverrideSource;
import 'editor/events_editor_controller.dart';
import 'editor/events_page.dart';
import 'editor/renown_editor_controller.dart';
import 'editor/renown_page.dart';
import 'editor/sprite_editor_controller.dart';
import 'editor/sprites_page.dart';
import '../../screen_editor/presentation/screen_editor_controller.dart';
import '../../screen_editor/presentation/screen_editor_page.dart';
import 'monitoring_page.dart';
import 'patch_page.dart';

/// Áreas del Editor (docs/specs/game_editor.md § 6).
enum EditorArea {
  monitoring,
  balance,
  visuals,
  layout,
  screens,
  npcs,
  events,
  climate,
  renown
}

/// Tab label of the CLIMA area (weather_seasons.md § 8).
const _climateTab = 'CLIMA';

/// El Editor del juego (game_editor.md; antes "admin de balance",
/// balance_admin.md § 5): Monitoreo · Balance · Visuales. Tema Material
/// oscuro de base (es una herramienta) con la estructura del sistema de
/// diseño (design_system.md).
class AdminApp extends StatelessWidget {
  const AdminApp(
      {super.key,
      required this.controller,
      this.sprites,
      this.animations,
      this.layouts,
      this.screens,
      this.npcs,
      this.events,
      this.climate,
      this.renown,
      this.animateFx = true,
      this.initialArea = EditorArea.balance,
      this.initialVisualTab = 0});
  final AdminController controller;

  /// LAYOUT (editor_layout.md § 3; `null`: sin área de layout).
  final LayoutEditorController? layouts;

  /// PANTALLAS (screen_editor.md § 5; `null`: sin área).
  final ScreenEditorController? screens;
  /// NPC (npc_editor.md; `null`: sin área de habitantes).
  final NpcEditorController? npcs;

  /// EVENTOS (world_events.md § 7; `null`: sin área).
  final EventsEditorController? events;
  /// CLIMA (weather_seasons.md § 8; `null`: sin área de clima).
  final ClimateEditorController? climate;

  /// RENOMBRE (renown_town_growth.md § 8; `null`: sin área).
  final RenownEditorController? renown;

  /// Visuales → Sprites (`null`: área sin catálogo, p. ej. tests de
  /// balance).
  final SpriteEditorController? sprites;

  /// Visuales → Animaciones (`null`: sin catálogo de fx).
  final FxEditorController? animations;

  /// El preview de animaciones avanza solo (`false` en capturas).
  final bool animateFx;
  final EditorArea initialArea;
  final int initialVisualTab;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Ecos del Tiempo — Editor',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          brightness: Brightness.dark,
          colorSchemeSeed: const Color(0xFF7C5CFF),
          scaffoldBackgroundColor: DsColors.background,
          useMaterial3: true,
          visualDensity: VisualDensity.compact,
        ),
        home: AdminShell(
            controller: controller,
            sprites: sprites,
            animations: animations,
            layouts: layouts,
            screens: screens,
            npcs: npcs,
            events: events,
            climate: climate,
            renown: renown,
            animateFx: animateFx,
            initialArea: initialArea,
            initialVisualTab: initialVisualTab),
      );
}

class AdminShell extends StatefulWidget {
  const AdminShell(
      {super.key,
      required this.controller,
      this.sprites,
      this.animations,
      this.layouts,
      this.screens,
      this.npcs,
      this.events,
      this.climate,
      this.renown,
      this.animateFx = true,
      this.initialArea = EditorArea.balance,
      this.initialVisualTab = 0});
  final AdminController controller;
  final SpriteEditorController? sprites;

  /// LAYOUT (editor_layout.md § 3).
  final LayoutEditorController? layouts;

  /// PANTALLAS (screen_editor.md § 5).
  final ScreenEditorController? screens;
  /// NPC (npc_editor.md; `null`: sin área de habitantes).
  final NpcEditorController? npcs;

  /// EVENTOS (world_events.md § 7; `null`: sin área).
  final EventsEditorController? events;
  /// CLIMA (weather_seasons.md § 8; `null`: sin área de clima).
  final ClimateEditorController? climate;

  /// RENOMBRE (renown_town_growth.md § 8; `null`: sin área).
  final RenownEditorController? renown;

  /// Visuales → Animaciones (`null`: sin catálogo de fx).
  final FxEditorController? animations;

  /// El preview de animaciones avanza solo (`false` en capturas).
  final bool animateFx;
  final EditorArea initialArea;
  final int initialVisualTab;

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  late EditorArea area = widget.initialArea;
  int balanceTab = 0;
  late int visualTab = widget.initialVisualTab;
  final _search = TextEditingController();

  /// Visuales → VARIANTES NPC (npc_variants.md § 5), creado al abrirlo.
  NpcVariantsController? _variants;

  NpcVariantsController? get variants {
    final s = widget.sprites;
    if (s == null) return null;
    final o = s.overrides;
    return _variants ??= NpcVariantsController(
        catalog: s.catalog,
        store: o is NpcVariantsOverrideSource
            ? o as NpcVariantsOverrideSource
            : null);
  }

  @override
  void dispose() {
    _search.dispose();
    _variants?.dispose();
    super.dispose();
  }

  /// Buscador global: filtra el área activa.
  void _onSearch(String q) {
    switch (area) {
      case EditorArea.balance:
        widget.controller.setQuery(q);
        if (balanceTab != 0) setState(() => balanceTab = 0);
      case EditorArea.visuals:
        if (visualTab == 1) {
          widget.animations?.setQuery(q);
        } else {
          widget.sprites?.setQuery(q);
        }
      case EditorArea.monitoring:
      case EditorArea.layout:
      case EditorArea.screens:
      case EditorArea.npcs:
      case EditorArea.events:
      case EditorArea.climate:
      case EditorArea.renown:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return ListenableBuilder(
      listenable: Listenable.merge([
        c,
        if (widget.sprites != null) widget.sprites!,
        if (widget.animations != null) widget.animations!,
        if (widget.npcs != null) widget.npcs!,
        if (widget.events != null) widget.events!,
        if (widget.climate != null) widget.climate!,
        if (widget.renown != null) widget.renown!,
      ]),
      builder: (context, _) {
        final pending = c.pendingChanges.length;
        final overrides = (widget.sprites?.overrideCount ?? 0) +
            (widget.animations?.overrideCount ?? 0);
        return Scaffold(
          body: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            DsToolbar(
              title: 'EDITOR',
              center: DsTabBar(
                key: const ValueKey('editor-areas'),
                index: area.index,
                onChanged: (i) => setState(() {
                  area = EditorArea.values[i];
                  _search.clear();
                }),
                tabs: [
                  const DsTab('MONITOREO'),
                  DsTab('BALANCE', badge: pending > 0 ? '$pending' : null),
                  DsTab('VISUALES', badge: overrides > 0 ? '$overrides' : null),
                  const DsTab('LAYOUT'),
                  const DsTab('PANTALLAS'),
                  DsTab('NPC',
                      badge: widget.npcs?.dirty ?? false ? '!' : null),
                  DsTab('EVENTOS',
                      badge: widget.events?.dirty ?? false ? '!' : null),
                  DsTab(_climateTab,
                      badge: widget.climate?.dirty ?? false ? '!' : null),
                  DsTab('RENOMBRE',
                      badge: widget.renown?.dirty ?? false ? '!' : null),
                ],
              ),
              actions: [
                if (area == EditorArea.balance || area == EditorArea.visuals)
                  DsSearchField(
                      key: const ValueKey('editor-search'),
                      controller: _search,
                      hint: area == EditorArea.balance
                          ? 'BUSCAR (NOMBRE, ID, CAMPO)'
                          : visualTab == 1
                              ? 'BUSCAR ANIMACIÓN'
                              : 'BUSCAR SPRITE',
                      width: 300,
                      onChanged: _onSearch),
                Text(
                  'balance ${c.validDraft.hash}'
                  '${c.currentVersion == null ? '' : ' · v${c.currentVersion}'}',
                  style: DsText.detail(),
                ),
                DsButton('GUARDAR',
                    key: const ValueKey('editor-save'),
                    kind: DsButtonKind.primary,
                    onPressed: c.canSave && pending > 0 ? c.save : null),
              ],
            ),
            Expanded(child: _area(c, pending)),
          ]),
        );
      },
    );
  }

  Widget _area(AdminController c, int pending) {
    switch (area) {
      case EditorArea.monitoring:
        return MonitoringPage(c: c);
      case EditorArea.npcs:
        final n = widget.npcs;
        return n == null
            ? Center(child: Text('SIN ÁREA DE NPC', style: DsText.detail()))
            : NpcsPage(c: n);
      case EditorArea.events:
        final ev = widget.events;
        return ev == null
            ? Center(child: Text('SIN ÁREA DE EVENTOS', style: DsText.detail()))
            : EventsPage(c: ev);
      case EditorArea.climate:
        final cl = widget.climate;
        return cl == null ? const SizedBox.shrink() : ClimatePage(c: cl);
      case EditorArea.renown:
        final rn = widget.renown;
        return rn == null
            ? Center(child: Text('SIN ÁREA DE RENOMBRE', style: DsText.detail()))
            : RenownPage(c: rn);
      case EditorArea.layout:
        final l = widget.layouts;
        return l == null
            ? Center(child: Text('SIN ÁREA DE LAYOUT', style: DsText.detail()))
            : LayoutPage(c: l);
      case EditorArea.screens:
        final sc = widget.screens;
        return sc == null
            ? Center(child: Text('SIN ÁREA DE PANTALLAS', style: DsText.detail()))
            : ScreenEditorPage(c: sc);
      case EditorArea.balance:
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          DsTabBar(
            key: const ValueKey('balance-tabs'),
            index: balanceTab,
            onChanged: (i) => setState(() => balanceTab = i),
            tabs: [
              const DsTab('Entidades'),
              DsTab('Cambios', badge: pending > 0 ? '$pending' : null),
              const DsTab('Parche'),
            ],
          ),
          Expanded(
            child: [
              BalancePage(c: c),
              ChangesPage(c: c),
              PatchPage(c: c),
            ][balanceTab],
          ),
        ]);
      case EditorArea.visuals:
        final s = widget.sprites;
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          DsTabBar(
            key: const ValueKey('visual-tabs'),
            index: visualTab,
            onChanged: (i) => setState(() {
              visualTab = i;
              _search.clear();
            }),
            tabs: [
              const DsTab('SPRITES'),
              const DsTab('ANIMACIONES'),
              DsTab(GameText.t('ui.world.npcv.tab')),
            ],
          ),
          Expanded(
            child: visualTab == 2
                ? variants == null
                    ? const SizedBox.shrink()
                    : NpcVariantsPage(c: variants!)
                : visualTab == 1
                ? widget.animations == null
                    ? Center(
                        child: Text('SIN CATÁLOGO DE ANIMACIONES',
                            style: DsText.detail()))
                    : AnimationsPage(
                        c: widget.animations!, ticking: widget.animateFx)
                : s == null
                    ? Center(child: Text('SIN CATÁLOGO DE SPRITES', style: DsText.detail()))
                    : SpritesPage(c: s),
          ),
        ]);
    }
  }
}
