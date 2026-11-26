// Goldens de los componentes del sistema de diseño (fuentes reales, ALTO
// CONTRASTE). Regenerar: flutter test --update-goldens test/design/ds_golden_test.dart
@Tags(['golden'])
library;

import 'package:echos_del_tiempo/app/design/design.dart';
import 'package:echos_del_tiempo/app/design/gallery/ds_examples.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../real_fonts.dart';
import 'ds_harness.dart';

void main() {
  void noop() {}
  final cases = <String, Widget>{
    'buttons': Wrap(spacing: 8, runSpacing: 8, children: [
      DsButton('EQUIPAR', kind: DsButtonKind.primary, onPressed: noop),
      DsButton('COMPARAR', onPressed: noop),
      DsButton('COMPARAR', selected: true, onPressed: noop),
      DsButton('> MAS', kind: DsButtonKind.ghost, onPressed: noop),
      const DsButton('TIRAR', onPressed: null),
      DsButton('HOVER',
          onPressed: noop, previewStates: const {WidgetState.hovered}),
      DsButton('FOCO',
          onPressed: noop, previewStates: const {WidgetState.focused}),
      DsButton('+3 VIT', size: DsButtonSize.compact, onPressed: noop),
      DsButton.icon(const Text('?'), tooltip: 'Ayuda', onPressed: noop),
    ]),
    'tabs': SizedBox(
      width: 900,
      child: DsToolbar(
        title: 'PERSONAJE',
        center: DsTabBar(tabs: const [
          DsTab('ESTADO', badge: '4'),
          DsTab('EQUIPO'),
          DsTab('PASIVAS', badge: 'NUEVO'),
        ], index: 0, onChanged: (_) {}),
        actions: [
          DsButton.icon(const Text('?'),
              tooltip: 'Ayuda', size: DsButtonSize.compact, onPressed: noop),
        ],
      ),
    ),
    'rows': SizedBox(
      width: 600,
      child: Column(children: [
        DsListRow(title: 'Espada del Alba', detail: 'Nv 12', onTap: noop),
        DsListRow(title: 'Arco', detail: 'Nv 9', selected: true, onTap: noop),
        const DsListRow(
            title: 'Tormenta',
            detail: 'Falta MP',
            detailColor: DsColors.danger,
            enabled: false,
            trailing: DsCost.mp(40, affordable: false)),
        DsAttributeRow(
            name: 'Agilidad',
            code: 'AGI',
            value: 61,
            planned: true,
            cappedStep: 1.5,
            onAdd: noop,
            onRemove: noop),
      ]),
    ),
    'values': const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DsStatLine('ATQ', 15, 50),
          DsStatLine('DEF', 30, 22),
          Row(mainAxisSize: MainAxisSize.min, children: [
            DsCost.mp(8),
            SizedBox(width: 16),
            DsCost.pulse(2),
            SizedBox(width: 16),
            DsTag.instant(),
            SizedBox(width: 8),
            DsTag.canBreak(),
            SizedBox(width: 8),
            DsTag.isNew(),
          ]),
        ]),
    'surfaces': SizedBox(
      width: 500,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const DsSectionHeader('Avisos'),
        DsToast('Equipaste Espada del Alba',
            kind: DsToastKind.success, onClose: noop),
        const SizedBox(height: 8),
        DsCard(onTap: noop, child: const Text('Tarjeta')),
        const SizedBox(height: 8),
        const DsSearchField(),
      ]),
    ),
    'tooltip': const WeaponTooltip(),
    'quest_template': SizedBox(
      width: 900,
      height: 420,
      child: DsQuestTemplate(
          entries: QuestTemplateMockup.entries(),
          empty: '-',
          itemsLabel: 'PIDE',
          rewardsLabel: 'RECOMPENSA'),
    ),
    'text_hierarchy': Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final e in DsText.hierarchy.entries)
          Text('${e.key} — Trucha de río', style: e.value),
      ],
    ),
  };

  for (final e in cases.entries) {
    testWidgets('golden ${e.key}', (tester) async {
      await loadRealFonts(tester);
      await pumpDs(tester, e.value);
      await expectLater(
          find.byKey(dsShotKey), matchesGoldenFile('goldens/ds_${e.key}.png'));
    });
  }
}
