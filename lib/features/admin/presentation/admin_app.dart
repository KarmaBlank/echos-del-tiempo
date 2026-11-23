import 'package:material_ui/material_ui.dart';

import '../../../app/design/design.dart';
import 'admin_controller.dart';
import 'balance_page.dart';
import 'changes_page.dart';
import 'editor/animations_page.dart';
import 'editor/fx_editor_controller.dart';
import 'editor/layout_editor_controller.dart';
import 'editor/layout_page.dart';
import 'editor/npc_editor_controller.dart';
import 'editor/npcs_page.dart';
import 'editor/sprite_editor_controller.dart';
import 'editor/sprites_page.dart';
import 'monitoring_page.dart';
import 'patch_page.dart';

/// Áreas del Editor (docs/specs/game_editor.md § 6).
enum EditorArea { monitoring, balance, visuals, layout, npcs }

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
      this.npcs,
      this.animateFx = true,
      this.initialArea = EditorArea.balance,
      this.initialVisualTab = 0});
  final AdminController controller;

  /// LAYOUT (editor_layout.md § 3; `null`: sin área de layout).
  final LayoutEditorController? layouts;

  /// NPC (npc_editor.md; `null`: sin área de habitantes).
  final NpcEditorController? npcs;

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
            npcs: npcs,
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
      this.npcs,
      this.animateFx = true,
      this.initialArea = EditorArea.balance,
      this.initialVisualTab = 0});
  final AdminController controller;
  final SpriteEditorController? sprites;

  /// LAYOUT (editor_layout.md § 3).
  final LayoutEditorController? layouts;

  /// NPC (npc_editor.md; `null`: sin área de habitantes).
  final NpcEditorController? npcs;

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

  @override
  void dispose() {
    _search.dispose();
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
      case EditorArea.npcs:
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
                  DsTab('NPC',
                      badge: widget.npcs?.dirty ?? false ? '!' : null),
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
      case EditorArea.layout:
        final l = widget.layouts;
        return l == null
            ? Center(child: Text('SIN ÁREA DE LAYOUT', style: DsText.detail()))
            : LayoutPage(c: l);
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
            tabs: const [DsTab('SPRITES'), DsTab('ANIMACIONES')],
          ),
          Expanded(
            child: visualTab == 1
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
