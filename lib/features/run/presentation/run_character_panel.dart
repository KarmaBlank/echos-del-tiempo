import '../../../game_engine/data/run_boons.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/design/design.dart';
import '../../../app/theme/panel_frame.dart';
import '../../combat/domain/skill_text.dart';
import '../../../game_engine/models/attributes.dart';
import '../../../game_engine/models/player_profile.dart';
import '../../../game_engine/models/run_state.dart';
import '../../../game_engine/rules/run_tuning.dart';
import '../../../game_engine/rules/ult_rules.dart';
import '../../inventory/presentation/inventory_tab.dart';
import '../../inventory/presentation/shop_sections.dart';
import '../../passive_tree/domain/passive_text.dart';
import '../../world/presentation/session_controller.dart';
import '../../world/presentation/session_view.dart';

/// Pestañas del personaje de la Travesía.
enum RunCharacterTab {
  resumen('LO QUE LLEVO'),
  inventory('EQUIPAMIENTO');

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

/// Qué hace cada atributo en la Travesía (tooltip).
String runAttributeHelp(Attribute a) => switch (a) {
      Attribute.vit => 'Más vida máxima.',
      Attribute.fue => 'Más ATQ con armas que escalan con Fuerza.',
      Attribute.esp => 'Más maná máximo y MAG con armas mágicas.',
      Attribute.des => 'Más ATQ con armas de Destreza y más crítico.',
      Attribute.agi => 'No se usa en la Travesía.',
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
      closeOnTab: true,
      titleTrailing: Flexible(
        child: Text('${prof.name}  $cls',
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
    final run = widget.view.session.run ?? RunState(seed: 0, zones: const []);
    final actorId = widget.view.actorId;
    final equipped = run.loadout[actorId] ?? const <String>[];
    final stored = run.skills[actorId] ?? const <String>[];
    final boons = <String, int>{};
    for (final b in widget.view.session.run?.boons[widget.view.actor!.id] ??
        const <String>[]) {
      boons[b] = (boons[b] ?? 0) + 1;
    }

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
            DsTooltip(
              card: DsTooltipCard(
                title: runAttributeName(a),
                children: [
                  Text(runAttributeHelp(a)),
                  Text(
                      'Base de la clase ${base[a]}. Sube solo con '
                      'recompensas de atributo.',
                      style: DsText.detail()),
                ],
              ),
              child: Text(
                  '${runAttributeName(a)} ${prof.attributes[a]}'
                  '${prof.attributes[a] > base[a] ? '  (+${prof.attributes[a] - base[a]} en la run)' : ''}',
                  key: ValueKey('run-attr-${a.name}'),
                  style: DsText.body()),
            ),
        ]),
        section('ARMA', [
          Text(
              item == null
                  ? weapon.name
                  : rules.weaponDisplayName(prof, item.uid),
              style: DsText.subtitle()),
          Wrap(
            key: const ValueKey('run-weapon-skills'),
            spacing: DsSpace.xs,
            children: [
              Text('trae:', style: DsText.detail()),
              for (final (i, id) in rules.weaponSkills(prof).indexed)
                if (catalog.skills[id] case final sk?)
                  RetroTooltip(
                    message: describeSkillMarkup(sk, null),
                    child: Text(
                        '${sk.name}'
                        '${i < rules.weaponSkills(prof).length - 1 ? ',' : ''}',
                        style: DsText.body()),
                  ),
            ],
          ),
          Text('Se mejora en la armería (FORJA), junto con sus habilidades.',
              style: DsText.detail()),
        ]),
        section(
            'HABILIDADES (${equipped.length}/${RunTuning.freeSkillSlots})',
            [
              Text(
                  'Aparte de ATACAR, DEFENDER y las del arma. Tope '
                  '${RunTuning.freeSkillSlots + 2} contando ATACAR y '
                  'DEFENDER.',
                  style: DsText.detail()),
              if (equipped.isEmpty && stored.isEmpty)
                Text('Todavía no tenés ninguna.', style: DsText.detail()),
              for (final id in [...equipped, ...stored])
                if (catalog.skills[id] case final sk?)
                  Padding(
                    padding: EdgeInsets.only(bottom: DsSpace.xs),
                    child: Row(children: [
                      Expanded(
                        child: RetroTooltip(
                          message: describeSkillMarkup(sk, null),
                          child: Text(
                              '${sk.name}'
                              '${run.skillLevel(actorId, id) > 0 ? '  +${run.skillLevel(actorId, id)}' : ''}'
                              '${sk.mp > 0 ? ' · ${sk.mp} MP' : ''}',
                              style: DsText.body(equipped.contains(id)
                                  ? DsColors.text
                                  : DsColors.textSecondary)),
                        ),
                      ),
                      if (equipped.contains(id))
                        DsButton('GUARDAR',
                            key: ValueKey('run-skill-off-$id'),
                            size: DsButtonSize.compact,
                            tooltip: canSwitch ? null : 'Fuera de combate',
                            onPressed: canSwitch
                                ? () => c.setRunSkill(id, equip: false)
                                : null)
                      else
                        DsButton('EQUIPAR',
                            key: ValueKey('run-skill-on-$id'),
                            size: DsButtonSize.compact,
                            tooltip: !canSwitch
                                ? 'Fuera de combate'
                                : equipped.length >= RunTuning.freeSkillSlots
                                    ? 'Sin lugar: guardá otra primero'
                                    : null,
                            onPressed: canSwitch &&
                                    equipped.length < RunTuning.freeSkillSlots
                                ? () => c.setRunSkill(id, equip: true)
                                : null),
                    ]),
                  ),
            ]),
        section('BOLSO', [
          Text(
              '${prof.items.length} arma${prof.items.length == 1 ? '' : 's'} '
              '· Pociones ${prof.potions} · Éter ${prof.ethers} · '
              'Oro ${prof.credits}',
              style: DsText.body()),
          Text('Equipar y ordenar: EQUIPAMIENTO [I].', style: DsText.detail()),
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
        section('MEJORAS', [
          if (boons.isEmpty)
            Text('Todavía no tomaste ninguna.', style: DsText.detail()),
          for (final e in boons.entries)
            DsTooltip(
              card: DsTooltipCard(
                title: 'Mejora directa',
                children: [
                  Text(RunBoon.byName(e.key)?.text ?? e.key),
                  Text('Dura toda la run; se apila si la repetís.',
                      style: DsText.detail()),
                ],
              ),
              child: Text(
                  '${RunBoon.byName(e.key)?.text ?? e.key}'
                  '${e.value > 1 ? '  ×${e.value}' : ''}',
                  style: DsText.body()),
            ),
        ]),
        section('OBJETOS DE LA RUN', [
          if (byPath.isEmpty)
            Text('Todavía no tomaste ninguno.', style: DsText.detail()),
          for (final e in byPath.entries) ...[
            // La rama solo agrupa (sutil); cada objeto: nombre y efecto.
            Text(tree.paths[e.key]?.name ?? e.key, style: DsText.detail()),
            for (final id in e.value)
              Padding(
                padding: EdgeInsets.only(bottom: DsSpace.xs),
                child: Column(
                  key: ValueKey('run-item-$id'),
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tree.nodes[id]!.name, style: DsText.subtitle()),
                    for (final l in passiveEffectsClean(tree.nodes[id]!))
                      Text(l, style: DsText.body()),
                  ],
                ),
              ),
          ],
        ]),
      ],
    );
  }
}
