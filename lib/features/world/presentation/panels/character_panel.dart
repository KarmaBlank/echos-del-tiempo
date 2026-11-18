import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/feature_flags.dart';
import '../../../ascension/domain/ascension_text.dart';
import '../../../build_planner/presentation/build_fit_badge.dart';
import '../../../build_planner/presentation/build_plan_providers.dart';
import '../../../build_planner/presentation/build_planner_view.dart';
import '../../../../app/theme/panel_frame.dart';
import '../../../../app/theme/panel_widgets.dart';
import '../../../../app/theme/proto_colors.dart';
import '../../../../app/theme/proto_markup.dart';
import '../../../../app/theme/retro_text.dart';
import '../../../../app/theme/retro_theme.dart';
import '../../../../app/widgets/menu_focus.dart';
import '../../../../app/widgets/pixel_icon.dart';
import '../../../../app/widgets/section_panel.dart';
import '../../../../game_engine/models/attributes.dart';
import '../../../../game_engine/models/game_session.dart';
import '../../../../game_engine/rules/progression_rules.dart';
import '../../../endgame/domain/endgame_text.dart';
import '../../../inventory/domain/battle_impact.dart';
import '../../../inventory/presentation/inventory_tab.dart';
import '../../../inventory/presentation/loot_filter_tab.dart';
import '../../../inventory/presentation/shop_sections.dart';
import '../../../passive_tree/presentation/passive_tree_view.dart';
import '../session_controller.dart';
import '../session_view.dart';

/// Nombre y efecto de cada atributo (`STATN`, `STATD` del prototipo).
const kAttributeInfo = {
  Attribute.vit: ('VIT', 'Vitalidad', '+4 vida máx.'),
  Attribute.esp: ('ESP', 'Espíritu', '+1.5 maná y poder mágico'),
  Attribute.agi: ('AGI', 'Agilidad', '+0.5 velocidad: turnos más seguidos'),
  Attribute.fue: ('FUE', 'Fuerza', 'daño de armas pesadas'),
  Attribute.des: (
    'DES',
    'Destreza',
    '+1.2% crítico, +0.1 velocidad, armas de precisión'
  ),
};

/// Pestañas del panel de personaje.
enum CharacterTab {
  attributes(
      'ATRIBUTOS',
      'Reparte puntos con + y -; nada cambia hasta CONFIRMAR. Cada nivel da '
          '${ProgressionRules.pointsPerLevel} puntos.'),
  inventory(
      'INVENTARIO',
      'Arrastra para mover · clic para ver · EQUIPAR, DAR A, TIRAR, DESARMAR '
          '(materiales) o VENDER (créditos). ORDENAR · LIMPIAR INVENTARIO: '
          'por rareza o elegidas a mano.'),
  tree(
      'ÁRBOL',
      'Pasivas de clase: 1 punto por nivel. Arrastra para mover, rueda para '
          'zoom, clic para tomar un nodo.'),
  filter(
      'FILTRO',
      'Reglas en orden: gana la primera que coincide. Ocultar no borra el '
          'loot: lo deja en el piso. Ayuda de la gramática en [?] y abajo.'),
  build(
      'BUILD',
      'Tu plan: metas con progreso automático. ★ marca en tienda, '
          'inventario y fusión lo que sirve; te avisa cuando avanzás.');

  const CharacterTab(this.label, this.hint);
  final String label;
  final String hint;
}

/// Panel de personaje (`char` del prototipo, líneas 1298-1335): atributos
/// con vista previa del reparto al costado, armas con comparación y
/// árbol de pasivas. Se abre solo y no se puede cerrar mientras
/// `mustAllocate`. Ver docs/specs/panels.md § "Personaje".
class CharacterPanel extends StatefulWidget {
  const CharacterPanel({
    super.key,
    required this.view,
    required this.controller,
    this.initialTab = CharacterTab.attributes,
  });

  final SessionView view;
  final SessionController controller;
  final CharacterTab initialTab;

  static const help = '<b>Personaje</b><br>'
      '<span class="k">ATRIBUTOS</span>: reparte los puntos de nivel; a la '
      'derecha ves cómo cambian tus stats antes de confirmar.<br>'
      '<span class="k">INVENTARIO</span> (tecla I): tus objetos; equipa, '
      'compara, tira o da a un compañero.<br>'
      '<span class="k">ÁRBOL</span>: pasivas de clase.<br>'
      '<span class="k">FILTRO</span>: qué loot ves y cómo se marca.<br>'
      'Reiniciar puntos o árbol es gratis (salvo en batalla).';

  @override
  State<CharacterPanel> createState() => _CharacterPanelState();
}

class _CharacterPanelState extends State<CharacterPanel> {
  final _alloc = <Attribute, int>{};
  late var _tab = widget.initialTab;

  int get _allocSum => _alloc.values.fold(0, (a, b) => a + b);

  @override
  Widget build(BuildContext context) {
    final view = widget.view;
    final c = widget.controller;
    final prof = view.me!.profile;
    final rules = c.engine.progression;
    final guards = ShopContext(view, c).guards;
    final must = view.mustAllocate;
    final left = prof.points - _allocSum;
    final cls = rules.catalog.classes[prof.classId]?.name ?? prof.classId;
    // Durante la subida de nivel se reparte primero.
    final tab = must ? CharacterTab.attributes : _tab;
    final close = must ? null : c.closePanel;

    final Widget body = switch (tab) {
      CharacterTab.attributes => _attributes(),
      CharacterTab.inventory =>
        InventoryTab(shop: ShopContext(view, c), pending: Map.of(_alloc)),
      CharacterTab.filter => LootFilterTab(shop: ShopContext(view, c)),
      CharacterTab.build => Consumer(
          builder: (context, ref, _) => BuildPlannerView(
                key: const ValueKey('build-planner'),
                rules: ref.watch(buildPlanRulesProvider),
                profile: prof,
                plan: ref.watch(buildPlanProvider).plan,
                onChanged: (p) => ref.read(buildPlanProvider.notifier).save(p),
              )),
      // El visor del árbol se ajusta al alto que queda (fila de puntos y
      // reinicio arriba: ~40 px).
      CharacterTab.tree => LayoutBuilder(
          builder: (context, box) => SingleChildScrollView(
              child: _tree((box.maxHeight - 44).clamp(240.0, 420.0)))),
    };

    final closeButton = view.mode == SessionMode.prep
        ? PanelButton('< VOLVER A PREPARACIÓN',
            reason: must ? 'Reparte tus puntos' : null, onPressed: close)
        : PanelButton('CERRAR [ESC]',
            reason: must ? 'Reparte tus puntos' : null, onPressed: close);
    final isAttr = tab == CharacterTab.attributes;

    // Q / E, Ctrl+Tab y 1-5 cambian de pestaña (menu_focus.dart); no
    // mientras hay que repartir.
    return MenuTabKeys(
        count: CharacterTab.values.length,
        index: tab.index,
        enabled: !must,
        onChanged: (i) => setState(() => _tab = CharacterTab.values[i]),
        child: PanelFrame(
          title: must
              ? '¡SUBISTE A NIVEL ${prof.level}! Reparte tus puntos'
              : 'PERSONAJE',
          width: 1000,
          fill: true,
          help: switch (tab) {
            CharacterTab.filter => kFilterHelp,
            CharacterTab.build => BuildPlannerView.help,
            _ => CharacterPanel.help,
          },
          onClose: close,
          titleTrailing: ProtoText('${protoEsc(profileTitle(prof))} · '
              '<span class="k">$cls Lv${prof.level}</span>'
              '${prof.level >= ProgressionRules.maxLevel ? ' · <span style="color:#a29bfe">${protoEsc(masteryText(prof))}</span>' : ''} · Puntos: '
              '<b>$left</b>'),
          header: must
              ? null
              : PanelTabs(
                  labels: [for (final t in CharacterTab.values) t.label],
                  index: tab.index,
                  onChanged: (i) =>
                      setState(() => _tab = CharacterTab.values[i]),
                ),
          leading: [
            if (isAttr && guards.showRespec)
              PanelButton(
                  ProgressionRules.freeRespec
                      ? 'REINICIAR PUNTOS (GRATIS)'
                      : 'REINICIAR PUNTOS',
                  key: const ValueKey('respec'),
                  reason: guards.respec(), onPressed: () {
                if (c.respec()) setState(_alloc.clear);
              }),
          ],
          actions: [
            if (isAttr)
              PanelButton('DESHACER',
                  key: const ValueKey('undo-points'),
                  onPressed:
                      _allocSum == 0 ? null : () => setState(_alloc.clear)),
            closeButton,
            if (isAttr)
              PanelButton('CONFIRMAR PUNTOS',
                  key: const ValueKey('confirm-points'),
                  accent: ProtoColors.green,
                  reason: guards.allocate(prof, _alloc),
                  onPressed: _confirm),
          ],
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PanelHint(tab.hint),
              Expanded(child: body),
            ],
          ),
        ));
  }

  // ---------------- atributos ----------------

  Widget _attributes() {
    final view = widget.view;
    final prof = view.me!.profile;
    final c = widget.controller;
    final rules = c.engine.progression;
    final guards = ShopContext(view, c).guards;
    final left = prof.points - _allocSum;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Con plan de build: el objetivo de cada atributo y a cuál
                // le faltan puntos (build_planner.md § 4.1).
                Consumer(builder: (context, ref, _) {
                  final plan = ref.watch(buildPlanProvider).plan;
                  final want = [
                    for (final a in Attribute.values)
                      if ((plan.attributes[a] ?? 0) > prof.attributes[a])
                        kAttributeInfo[a]!.$1,
                  ];
                  return SectionPanel(
                    icon: PixelIconKind.plus,
                    title: 'ATRIBUTOS',
                    subtitle:
                        left > 0 ? 'Puntos libres: $left' : 'Sin puntos libres',
                    children: [
                      if (want.isNotEmpty && prof.points > 0)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                              retroText('★ Según tu build: ${want.join(', ')}'),
                              key: const ValueKey('build-attr-hint'),
                              style: const TextStyle(color: kPlanColor)),
                        ),
                      InitialFocus(
                        enabled: left > 0,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final a in Attribute.values)
                              _attrRow(a, prof.attributes[a], left,
                                  target: plan.attributes[a]),
                          ],
                        ),
                      ),
                    ],
                  );
                }),
                if (view.mustAllocate)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 10),
                    child: Text(
                        'El equipo sigue cuando todos los que subieron de nivel '
                        'confirmen sus puntos.',
                        style: TextStyle(color: ProtoColors.orange)),
                  ),
                SectionPanel(
                  icon: PixelIconKind.sword,
                  title: 'CLASE',
                  subtitle: view.mode == SessionMode.lobby
                      ? 'Cambiar de clase reinicia atributos y árbol.'
                      : 'Solo en el lobby',
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final cl in rules.catalog.classes.values)
                          if (FeatureFlags.instance.isCharacterAllowed(cl.id))
                            PanelButton(cl.name,
                                key: ValueKey('class-${cl.id}'),
                                selected: cl.id == prof.classId,
                                onPressed: cl.id == prof.classId ||
                                        guards.changeClass(prof, cl.id) != null
                                    ? null
                                    : () {
                                        if (c.changeClass(cl.id)) {
                                          setState(_alloc.clear);
                                        }
                                      }),
                      ],
                    ),
                  ],
                ),
                if (prof.classId == 'paladin')
                  const SectionPanel(
                    icon: PixelIconKind.star,
                    title: 'RASGOS DE PALADÍN',
                    children: [
                      Text(
                        'Básico: 3% aturdir · habilidades según el arma\n'
                        'Débil a daño perforante (×1.5) y a estados (+1 stack)\n'
                        'Aura Restauradora, Fortaleza y Protección: kit del '
                        'Guardián (ascensión)',
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        SizedBox(width: RetroType.width(context, 380), child: _preview()),
      ],
    );
  }

  /// `previewOf`: stats con el reparto pendiente.
  Widget _preview() {
    final prof = widget.view.me!.profile;
    final rules = widget.controller.engine.progression;
    final now = rules.derivedStats(prof);
    final next = _allocSum == 0 ? now : rules.previewAllocation(prof, _alloc);
    final w = rules.equippedWeapon(prof);
    final pending = [
      for (final a in Attribute.values)
        if ((_alloc[a] ?? 0) > 0) '+${_alloc[a]} ${kAttributeInfo[a]!.$1}',
    ];
    String pct(num x) => '${(x * 100).round()}%';
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionPanel(
            icon: PixelIconKind.arrowIn,
            title: 'VISTA PREVIA',
            subtitle: 'cómo cambian tus stats',
            children: [
              StatChange('HP', now.maxHp, next.maxHp,
                  key: const ValueKey('stat-HP')),
              StatChange('MP', now.maxMp, next.maxMp,
                  key: const ValueKey('stat-MP')),
              StatChange('VEL', now.speed, next.speed,
                  key: const ValueKey('stat-VEL'),
                  format: (x) => x.toStringAsFixed(1)),
              Text(
                  retroText('  6 + AGI×0.5 + DES×0.1 − peso arma '
                      '${w.weight.toStringAsFixed(1)}'),
                  style: const TextStyle(color: ProtoColors.dim)),
              StatChange('ATQ', now.attack, next.attack,
                  key: const ValueKey('stat-ATQ')),
              StatChange('MAG', now.magic, next.magic,
                  key: const ValueKey('stat-MAG')),
              StatChange('DEF', now.defense, next.defense,
                  key: const ValueKey('stat-DEF'),
                  suffix: '(-${(next.defensePercent * 100).round()}% daño)'),
              StatChange('CRÍT', now.critChance, next.critChance,
                  key: const ValueKey('stat-CRIT'),
                  format: pct,
                  suffix: '(daño ×${now.critMultiplier == 2 ? '2' : '1.5'})'),
            ],
          ),
          SectionPanel(
            icon: PixelIconKind.check,
            title: 'PENDIENTE',
            children: [
              ProtoText(
                pending.isEmpty
                    ? protoColor(ProtoColors.dim, 'Sin cambios pendientes')
                    : 'Pendiente: ${protoColor(ProtoColors.green, pending.join(' '))}',
                key: const ValueKey('pending-points'),
              ),
              Text(retroText('Nada cambia hasta CONFIRMAR PUNTOS.'),
                  style: const TextStyle(color: ProtoColors.dim)),
            ],
          ),
        ],
      ),
    );
  }

  /// Un atributo como tarjeta: nombre, valor (+ reparto pendiente), meta
  /// del plan (★), `-` / `+` y qué hace, entero (en otra línea si no
  /// entra).
  Widget _attrRow(Attribute a, int value, int left, {int? target}) {
    final (short, name, desc) = kAttributeInfo[a]!;
    final add = _alloc[a] ?? 0;
    // Tooltip (mouse o foco en - / +): qué cambia en batalla con 1 punto
    // más (battle_impact.dart, tus números reales).
    final prof = widget.view.me!.profile;
    final rules = widget.controller.engine.progression;
    final now = _allocSum == 0
        ? rules.derivedStats(prof)
        : rules.previewAllocation(prof, _alloc);
    final next = rules.previewAllocation(prof, {..._alloc, a: add + 1});
    final impact =
        battleImpactMarkup(rules, now, next, weapon: rules.equippedItem(prof));
    return RetroTooltip(
        message: '<b>+1 ${retroText(name)}</b>: ${retroText(desc)}'
            '${impact == null ? '' : '<br>$impact'}',
        child: Container(
          key: ValueKey('attr-row-${a.name}'),
          margin: const EdgeInsets.only(bottom: 6),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: add > 0 ? ProtoColors.button.withValues(alpha: 0.4) : null,
            border: Border.all(
                color: add > 0 ? ProtoColors.green : ProtoColors.panelBorder,
                width: RetroTheme.thinBorderWidth),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  SizedBox(
                    width: RetroType.em(context, 15, size: RetroType.small),
                    child: ProtoText('<b style="color:#e8ecff">$short</b> '
                        '<span class="k">${retroText(name)}</span>'),
                  ),
                  SizedBox(
                    width: RetroType.em(context, 7, size: RetroType.small),
                    child: ProtoText('<b>$value</b>'
                        '${add > 0 ? ' ${protoColor(ProtoColors.green, '+$add')}' : ''}'),
                  ),
                  if (target != null)
                    SizedBox(
                      width: RetroType.em(context, 9, size: RetroType.small),
                      child: Text('★ ${value + add}/$target',
                          key: ValueKey('build-attr-${a.name}'),
                          style: TextStyle(
                              color: value + add >= target
                                  ? ProtoColors.green
                                  : kPlanColor)),
                    ),
                  const Spacer(),
                  PanelButton('-',
                      key: ValueKey('dec-${a.name}'),
                      onPressed: add > 0
                          ? () => setState(() => _alloc[a] = add - 1)
                          : null),
                  const SizedBox(width: 8),
                  PanelButton('+',
                      key: ValueKey('inc-${a.name}'),
                      onPressed: left > 0
                          ? () => setState(() => _alloc[a] = add + 1)
                          : null),
                ],
              ),
              Text(retroText(desc),
                  style: const TextStyle(color: ProtoColors.dim)),
            ],
          ),
        ));
  }

  void _confirm() {
    final add = {
      for (final e in _alloc.entries)
        if (e.value > 0) e.key: e.value,
    };
    if (widget.controller.allocate(add)) setState(_alloc.clear);
  }

  // ---------------- árbol ----------------

  Widget _tree(double height) {
    final view = widget.view;
    final c = widget.controller;
    final p = view.me!.profile;
    final guards = ShopContext(view, c).guards;
    return Consumer(
      builder: (context, ref, _) => PassiveTreeView(
        planned: ref.watch(buildPlanProvider).plan.treeNodes.toSet(),
        rules: c.engine.progression.treeRules,
        profile: p,
        inBattle: view.mode == SessionMode.battle,
        onTake: c.takeNode,
        showReset: guards.showRespec,
        resetLabel: ProgressionRules.freeRespec
            ? 'REINICIAR ÁRBOL (GRATIS)'
            : 'REINICIAR ÁRBOL',
        resetReason: guards.resetTree(p),
        onReset: c.resetTree,
        height: height,
        showHelp: false,
      ),
    );
  }
}
