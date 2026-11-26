// Static mockup of the visual layout editor (docs/specs/editor_layout.md,
// Parte II). Only runs with LAYOUT_MOCKUP=1:
//   $env:LAYOUT_MOCKUP = "1"; flutter test test/design/layout_editor_mockup_test.dart
// Writes docs/preview/layout_editor_mockup.png. Mock widget only: no
// editor logic, real Ds components.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:echos_del_tiempo/app/app.dart';
import 'package:echos_del_tiempo/app/design/ds_button.dart';
import 'package:echos_del_tiempo/app/design/ds_components.dart';
import 'package:echos_del_tiempo/app/design/ds_tokens.dart';
import 'package:echos_del_tiempo/app/theme/retro_type.dart';
import 'package:echos_del_tiempo/app/theme/ui_theme.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../real_fonts.dart';

final _on = Platform.environment['LAYOUT_MOCKUP'] != null;

void main() {
  testWidgets('layout editor mockup', (tester) async {
    await loadRealFonts(tester);
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(UiTheme.reset);
    addTearDown(RetroType.reset);
    final key = GlobalKey();
    await tester.pumpWidget(RepaintBoundary(
        key: key, child: const EcosApp(home: _LayoutEditorMockup())));
    await tester.pump();
    await tester.pump();
    await tester.runAsync(() async {
      final b =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final img = await b.toImage();
      final png = await img.toByteData(format: ui.ImageByteFormat.png);
      Directory('docs/preview').createSync(recursive: true);
      File('docs/preview/layout_editor_mockup.png')
          .writeAsBytesSync(png!.buffer.asUint8List());
      img.dispose();
    });
  }, skip: !_on);
}

void _noop() {}

class _LayoutEditorMockup extends StatelessWidget {
  const _LayoutEditorMockup();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DsColors.background,
      body: Column(children: [
        const DsToolbar(
          title: 'EDITOR · LAYOUT VISUAL · Mundo / npc_shop',
          actions: [
            DsButton('DESHACER', onPressed: _noop, size: DsButtonSize.compact),
            DsButton('REHACER', onPressed: null, size: DsButtonSize.compact),
            DsButton('1280×720', onPressed: _noop, size: DsButtonSize.compact),
            DsButton('VERIFICAR', onPressed: _noop, size: DsButtonSize.compact),
            DsButton('GUARDAR',
                onPressed: _noop,
                kind: DsButtonKind.primary,
                size: DsButtonSize.compact),
          ],
        ),
        Expanded(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const SizedBox(width: 400, child: _Tree()),
            Expanded(child: _Canvas()),
            const SizedBox(width: 460, child: _RightPanel()),
          ]),
        ),
        _Problems(),
      ]),
    );
  }
}

Widget _panel(Widget child, {bool scroll = false}) => Container(
      margin: EdgeInsets.all(DsSpace.xs),
      padding: EdgeInsets.all(DsSpace.sm),
      decoration: BoxDecoration(
          color: DsColors.surface,
          border: Border.all(color: DsColors.border, width: 2)),
      child: scroll ? SingleChildScrollView(child: child) : child,
    );

class _Tree extends StatelessWidget {
  const _Tree();

  @override
  Widget build(BuildContext context) {
    const rows = [
      ('▾ DsTransferTemplate', 0, false),
      ('▾ left · DsCollectionTemplate', 1, false),
      ('DsSearchField', 2, false),
      ('DsGridDetailLayout ← player.inventory', 2, true),
      ('▾ right · DsCollectionTemplate', 1, false),
      ('DsTabBar', 2, false),
      ('DsGridDetailLayout ← shop.stock', 2, false),
      ('▾ footer · DsActionRow', 1, false),
      ('DsButton → shop.buy', 2, false),
      ('DsButton → shop.sell', 2, false),
    ];
    return _panel(
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const DsSectionHeader('ÁRBOL'),
      for (final r in rows)
        Padding(
          padding: EdgeInsets.only(left: r.$2 * DsSpace.md),
          child: DsListRow(title: r.$1, selected: r.$3, onTap: _noop),
        ),
    ]));
  }
}

class _Canvas extends StatelessWidget {
  Widget _cell(String t, {bool sel = false}) => Container(
        width: 44,
        height: 44,
        margin: const EdgeInsets.all(2),
        alignment: Alignment.center,
        decoration: BoxDecoration(
            color: DsColors.surfaceSunken,
            border: Border.all(
                color: sel ? DsColors.selected : DsColors.borderControl,
                width: 2)),
        child: Text(t, style: DsText.detail()),
      );

  Widget _grid(String prefix, int n, {bool selected = false}) => Container(
        padding: EdgeInsets.all(DsSpace.xs),
        decoration: BoxDecoration(
            border: Border.all(
                color: selected ? DsColors.editSelection : DsColors.border,
                width: selected ? 3 : 1)),
        child: Wrap(children: [
          for (var i = 0; i < n; i++) _cell('$prefix${i + 1}', sel: i == 2)
        ]),
      );

  @override
  Widget build(BuildContext context) {
    return _panel(
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('LIENZO · vista previa en vivo · datos de ejemplo',
          style: DsText.detail()),
      SizedBox(height: DsSpace.sm),
      Expanded(
        child: Container(
          padding: EdgeInsets.all(DsSpace.md),
          color: DsColors.background,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('TIENDA DEL HERRERO', style: DsText.title()),
            SizedBox(height: DsSpace.sm),
            Expanded(
              child:
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const DsSectionHeader('TU INVENTARIO'),
                        const DsSearchField(width: 260),
                        SizedBox(height: DsSpace.sm),
                        SizedBox(
                            width: 300, child: _grid('I', 18, selected: true)),
                        SizedBox(height: DsSpace.xs),
                        Text('▲ seleccionado: DsGridDetailLayout',
                            style: DsText.detail(DsColors.editSelection)),
                      ]),
                ),
                SizedBox(width: DsSpace.md),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const DsSectionHeader('STOCK'),
                        DsTabBar(tabs: const [
                          DsTab('ARMAS'),
                          DsTab('CONSUMIBLES'),
                          DsTab('MATERIALES')
                        ], index: 0, onChanged: (_) {}),
                        SizedBox(height: DsSpace.sm),
                        SizedBox(width: 300, child: _grid('S', 12)),
                      ]),
                ),
              ]),
            ),
            Container(
              height: 4,
              color: DsColors.editSelection,
              margin: EdgeInsets.symmetric(vertical: DsSpace.xs),
            ),
            Text('↓ soltar acá: DsButton (insertar en footer, posición 2)',
                style: DsText.detail(DsColors.editSelection)),
            SizedBox(height: DsSpace.xs),
            Wrap(spacing: DsSpace.sm, children: const [
              DsButton('COMPRAR', onPressed: _noop, kind: DsButtonKind.primary),
              DsButton('VENDER', onPressed: _noop),
            ]),
          ]),
        ),
      ),
    ]));
  }
}

class _RightPanel extends StatelessWidget {
  const _RightPanel();

  @override
  Widget build(BuildContext context) {
    Widget kv(String k, String v, {Color? c}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(children: [
            SizedBox(width: 130, child: Text(k, style: DsText.detail())),
            Expanded(child: Text(v, style: DsText.body(c))),
          ]),
        );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Expanded(
        flex: 5,
        child: _panel(
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const DsSectionHeader('PALETA'),
              DsTabBar(tabs: const [
                DsTab('ÁTOMOS'),
                DsTab('MOLÉCULAS'),
                DsTab('ORGANISMOS'),
                DsTab('TEMPLATES'),
              ], index: 2, onChanged: (_) {}),
              SizedBox(height: DsSpace.xs),
              const DsSearchField(hint: 'BUSCAR COMPONENTE', width: 420),
              SizedBox(height: DsSpace.xs),
              const DsListRow(
                  title: 'DsGridDetailLayout', detail: 'colección + detalle'),
              const DsListRow(
                  title: 'DsActionRow',
                  detail: 'fila de acciones',
                  selected: true),
              const DsListRow(title: 'DsDialogueBox', detail: 'diálogo de NPC'),
              const DsListRow(title: 'DsCostGrid', detail: 'costos de receta'),
            ]),
            scroll: true),
      ),
      Expanded(
        flex: 6,
        child: _panel(
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const DsSectionHeader('PROPIEDADES'),
              kv('componente', 'DsGridDetailLayout'),
              kv('columnas', '6  (4–8)'),
              kv('tamaño celda', 'normal'),
              kv('borde', 'DsColors.border'),
              kv('texto', 'DsText.detail'),
              const DsSectionHeader('DATOS'),
              kv('fuente', 'player.inventory'),
              kv('tipo', 'List<ItemStack>', c: DsColors.success),
              kv('filtro', 'search(left.search)'),
              const DsSectionHeader('ACCIONES'),
              kv('al elegir', 'select → detail'),
              kv('doble clic', 'shop.sell(item)'),
            ]),
            scroll: true),
      ),
    ]);
  }
}

class _Problems extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _panel(Row(children: [
      Text('VERIFICAR: ', style: DsText.subtitle()),
      const DsChip('1 error', color: DsColors.danger),
      SizedBox(width: DsSpace.sm),
      Expanded(
        child: Text(
            'footer.DsButton[2]: acción shop.buy espera ItemStack, '
            'el binding da List<ItemStack>',
            style: DsText.detail(DsColors.danger)),
      ),
      const DsChip('0 avisos a 800×600', color: DsColors.success),
    ]));
  }
}
