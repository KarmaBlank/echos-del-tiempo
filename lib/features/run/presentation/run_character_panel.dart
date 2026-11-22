import 'package:material_ui/material_ui.dart';

import '../../../app/design/design.dart';
import '../../../app/theme/panel_frame.dart';
import '../../../game_engine/models/attributes.dart';
import '../../../game_engine/models/player_profile.dart';
import '../../../game_engine/rules/ult_rules.dart';
import '../../inventory/presentation/inventory_tab.dart';
import '../../inventory/presentation/shop_sections.dart';
import '../../passive_tree/domain/passive_text.dart';
import '../../world/presentation/session_controller.dart';
import '../../world/presentation/session_view.dart';

/// Pestañas del personaje de la Travesía.
enum RunCharacterTab {
  resumen('LO QUE LLEVO'),
  inventory('INVENTARIO');

  const RunCharacterTab(this.label);
  final String label;
}

/// Atributos de la Travesía (roguelike.md § 5): sin Agilidad.
const kRunAttributes = [
  Attribute.vit,
  Attribute.fue,
  Attribute.esp,
  Attribute.des,
];

String runAttributeName(Attribute a) => switch (a) {
      Attribute.vit => 'Vitalidad',
      Attribute.fue => 'Fuerza',
      Attribute.esp => 'Espíritu',
      Attribute.des => 'Destreza',
      Attribute.agi => 'Agilidad',
    };

/// Personaje de la Travesía (organismo, roguelike.md § 12): solo lo que
/// el jugador consiguió en esta run (atributos, arma y sus habilidades,
/// nodos tomados por rama, consumibles y ULT ganadas). Sin árbol, sin
/// reparto de puntos ni pestañas del Mundo.
class RunCharacterPanel extends StatefulWidget {
  const RunCharacterPanel({
    super.key,
    required this.view,
    required this.controller,
    this.initialTab = RunCharacterTab.resumen,
  });

  final SessionView view;
  final SessionController controller;
  final RunCharacterTab initialTab;

  @override
  State<RunCharacterPanel> createState() => _RunCharacterPanelState();
}

class _RunCharacterPanelState extends State<RunCharacterPanel> {
  late var _tab = widget.initialTab;

  @override
  Widget build(BuildContext context) {
    final view = widget.view;
    final c = widget.controller;
    final prof = view.actor!.profile;
    final cls = c.engine.catalog.classes[prof.classId]?.name ?? prof.classId;
    return PanelFrame(
      title: 'PERSONAJE',
      width: 1000,
      fill: true,
      onClose: c.closePanel,
      titleTrailing: Flexible(
        child: Text('${prof.name}  $cls Nv ${prof.level}',
            style: DsText.body(DsColors.textSubtitle)),
      ),
      header: DsTabBar(
        index: _tab.index,
        onChanged: (i) => setState(() => _tab = RunCharacterTab.values[i]),
        tabs: [
          for (final t in RunCharacterTab.values)
            DsTab(t.label, key: ValueKey('run-tab-${t.index}')),
        ],
      ),
      actions: [DsButton('CERRAR [ESC]', onPressed: c.closePanel)],
      child: switch (_tab) {
        RunCharacterTab.resumen => SingleChildScrollView(
            key: const ValueKey('run-character-summary'),
            child: _summary(prof),
          ),
        RunCharacterTab.inventory =>
          InventoryTab(shop: ShopContext(view, c), pending: const {}),
      },
    );
  }

  Widget _summary(PlayerProfile prof) {
    final c = widget.controller;
    final rules = c.engine.progression;
    final catalog = c.engine.catalog;
    final base = PlayerAttributes.base(
        catalog.classes[prof.classId]?.baseAttributes ?? const {});
    final weapon = rules.equippedWeapon(prof);
    final item = rules.equippedItem(prof);
    final tree = rules.treeRules.catalog;
    final byPath = <String, List<String>>{};
    for (final id in prof.tree) {
      final n = tree.nodes[id];
      if (n == null || n.kind == 'st') continue;
      (byPath[n.pathId ?? ''] ??= []).add(id);
    }
    final ults = UltRules.optionsOf(prof, weapon, item, catalog);
    final active = UltRules.validSel(prof, weapon, item, catalog);
    final canSwitch = widget.view.session.battle == null;

    Widget section(String title, List<Widget> rows) => Padding(
          padding: EdgeInsets.only(bottom: DsSpace.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DsSectionHeader(title),
              SizedBox(height: DsSpace.xs),
              ...rows,
            ],
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        section('ATRIBUTOS', [
          for (final a in kRunAttributes)
            Text(
                '${runAttributeName(a)} ${prof.attributes[a]}'
                '${prof.attributes[a] > base[a] ? '  (+${prof.attributes[a] - base[a]} en la run)' : ''}',
                key: ValueKey('run-attr-${a.name}'),
                style: DsText.body()),
        ]),
        section('ARMA', [
          Text(
              item == null
                  ? weapon.name
                  : rules.weaponDisplayName(prof, item.uid),
              style: DsText.subtitle()),
          for (final id in rules.weaponSkills(prof))
            if (catalog.skills[id] case final sk?)
              Text('${sk.name}${sk.mp > 0 ? ' · ${sk.mp} MP' : ''}',
                  style: DsText.body()),
          Text(
              'Bolso: ${prof.items.length} arma${prof.items.length == 1 ? '' : 's'} '
              '· Pociones ${prof.potions} · Éter ${prof.ethers} · '
              'Oro ${prof.credits}',
              style: DsText.detail()),
        ]),
        section('ULT', [
          for (final o in ults)
            Padding(
              padding: EdgeInsets.only(bottom: DsSpace.xs),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                        '${o.skill.name}${o.reason == null ? '' : '  (${o.reason})'}',
                        style: DsText.body(o.id == (active ?? ults.first.id)
                            ? DsColors.selected
                            : o.available
                                ? DsColors.text
                                : DsColors.textDisabled)),
                  ),
                  DsButton(
                      o.id == (active ?? ults.first.id) ? 'ACTIVA' : 'USAR',
                      key: ValueKey('run-ult-${o.id}'),
                      size: DsButtonSize.compact,
                      selected: o.id == (active ?? ults.first.id),
                      tooltip: !canSwitch
                          ? 'Fuera de combate'
                          : o.reason,
                      onPressed: !canSwitch ||
                              !o.available ||
                              o.id == (active ?? ults.first.id)
                          ? null
                          : () => c.selectUlt(o.id)),
                ],
              ),
            ),
          if (ults.isEmpty) Text('Sin ULT todavía.', style: DsText.detail()),
        ]),
        section('NODOS DE LA RUN', [
          if (byPath.isEmpty)
            Text('Todavía no tomaste ninguno.', style: DsText.detail()),
          for (final e in byPath.entries) ...[
            Text(tree.paths[e.key]?.name ?? e.key, style: DsText.subtitle()),
            for (final id in e.value)
              Text(
                  '${tree.nodes[id]!.name}: '
                  '${passiveEffectsText(tree.nodes[id]!).join(' · ')}',
                  style: DsText.body()),
          ],
        ]),
      ],
    );
  }
}
