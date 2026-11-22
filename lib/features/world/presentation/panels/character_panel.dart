import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/design/design.dart';
import '../../../../app/feature_flags.dart';
import '../../../ascension/domain/ascension_text.dart';
import '../../../characters/domain/unused_points.dart';
import '../../../characters/domain/xp_text.dart';
import '../../../characters/presentation/grimoire_section.dart';
import '../../../characters/presentation/ult_repertoire_view.dart';
import '../../../achievements/presentation/achievements_view.dart';
import '../../../bestiary/presentation/bestiary_view.dart';
import '../../../combat/presentation/game_sprites.dart';
import '../../../build_planner/domain/build_wants_of.dart';
import '../../../build_planner/presentation/build_fit_badge.dart';
import '../../../build_planner/presentation/build_plan_providers.dart';
import '../../../build_planner/presentation/build_planner_view.dart';
import '../../../../app/theme/panel_frame.dart';
import '../../../../app/theme/proto_colors.dart';
import '../../../../app/theme/proto_markup.dart';
import '../../../../app/theme/retro_text.dart';
import '../../../../app/theme/retro_theme.dart';
import '../../../../app/widgets/menu_focus.dart';
import '../../../../core/settings/settings_providers.dart';
import '../../../../game_engine/rules/build_guide_rules.dart';
import '../../../../game_engine/models/attributes.dart';
import '../../../../game_engine/models/bestiary.dart';
import '../../../../game_engine/models/build_plan.dart';
import '../../../../game_engine/models/player_profile.dart';
import '../../../../game_engine/models/game_session.dart';
import '../../../../game_engine/rules/attribute_advisor.dart';
import '../../../../game_engine/rules/progression_rules.dart';
import '../../../endgame/domain/endgame_text.dart';
import '../../../inventory/domain/battle_impact.dart';
import '../../../inventory/presentation/inventory_tab.dart';
import '../../../inventory/presentation/loot_filter_tab.dart';
import '../../../inventory/presentation/shop_sections.dart';
import '../../../passive_tree/presentation/passive_tree_view.dart';
import '../session_controller.dart';
import '../session_sfx.dart' show sfxServiceProvider;
import '../session_view.dart';
import 'party_member_bar.dart';
import '../../../../app/design/ds_layout_host.dart';
import '../../../../core/layout/layout_doc.dart';
import 'character_layout.dart';

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
      'Cada nivel da 1 punto (+3 a un atributo). Hasta el tope rinde '
          'completo; después, la mitad. Nada cambia hasta CONFIRMAR.'),
  inventory(
      'INVENTARIO',
      'Arrastra para mover · clic para ver · clic derecho (o Enter): '
          'acciones. ORDENAR · LIMPIAR INVENTARIO: por rareza o elegidas a '
          'mano.'),
  tree(
      'ÁRBOL',
      'Pasivas de clase: 1 punto por nivel. Clic en un nodo lejano: tomar el '
          'camino entero. Arrastra para mover, rueda para zoom.'),
  ults(
      'ULT',
      'Tu repertorio de ULT: elegí la activa y mejorala fuera de combate. '
          'Nada se pierde al vender o desarmar un arma.'),
  filter(
      'FILTRO',
      'Reglas en orden: gana la primera que coincide. Ocultar no borra el '
          'loot: lo deja en el piso. Ayuda de la gramática en [?] y abajo.'),
  build(
      'BUILD',
      'Tu plan: metas con progreso automático. ★ marca en tienda, '
          'inventario y fusión lo que sirve; te avisa cuando avanzás.'),
  bestiary(
      'BESTIARIO',
      'Los enemigos que derrotaste (toda la cuenta): familia, debilidades, '
          'resistencias y botín. Derrotá a los que faltan para descubrirlos.'),
  achievements(
      'HAZAÑAS',
      'Una vez por cuenta, con recompensa para el personaje que la logra. '
          'Pasá el mouse por una fila para ver cómo se consigue.');

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
    this.layout,
    this.layoutHooks,
  });

  /// Layout fijo (Editor → LAYOUT); `null` = el del catálogo
  /// (editor_layout.md § 6).
  final LayoutDoc? layout;
  final DsLayoutHooks? layoutHooks;

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

  /// La ranura de la cuenta del miembro activo (`null` = el elegido): su
  /// plan de build (solo_party.md § 6.2).
  String? get _slot => widget.controller.slotOf(widget.view.actorId);

  @override
  void didUpdateWidget(CharacterPanel old) {
    super.didUpdateWidget(old);
    // Otro miembro: el reparto pendiente era del anterior.
    if (old.view.actorId != widget.view.actorId) _alloc.clear();
  }

  @override
  Widget build(BuildContext context) {
    final view = widget.view;
    final c = widget.controller;
    final prof = view.actor!.profile;
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
      // Por miembro: el editor arranca con el filtro de ese miembro (sin
      // la clave, al cambiar de miembro quedaba el texto del anterior y
      // GUARDAR se lo pisaba al nuevo).
      CharacterTab.ults => Consumer(
          builder: (context, ref, _) => UltRepertoireView(
              key: ValueKey('ults-${view.actorId}'),
              profile: prof,
              weapon: rules.equippedWeapon(prof),
              item: rules.equippedItem(prof),
              editable: view.session.battle == null,
              onSelect: c.selectUlt,
              onUpgrade: c.upgradeUlt,
              onSeen: c.markSeen,
              // Filtros y orden, por equipo (ultimates_v2.md § 2.1.1).
              prefs: ref.read(gameSettingsProvider).ultBrowse,
              onPrefs: (p) => ref.read(gameSettingsProvider.notifier).update(
                  ref.read(gameSettingsProvider).copyWith(ultBrowse: p)),
              // Vista previa (ultimates_v2.md § 2.5).
              stats: rules.derivedStats(prof),
              sprites: ref.watch(gameSpritesProvider).valueOrNull,
              sfx: ref.read(sfxServiceProvider))),
      CharacterTab.filter => LootFilterTab(
          key: ValueKey('filter-tab-${view.actorId}'),
          shop: ShopContext(view, c)),
      CharacterTab.build => Consumer(
          builder: (context, ref, _) => BuildPlannerView(
                key: const ValueKey('build-planner'),
                rules: ref.watch(buildPlanRulesProvider),
                profile: prof,
                plan: ref.watch(buildPlanProvider).planFor(_slot),
                onEquip: c.equip,
                equipBlocked: (uid) =>
                    ShopContext(view, c).guards.equip(prof, uid),
                stash: stashWeapons(c.stash),
                onTakeNode: view.session.battle == null ? c.takeNode : null,
                onChanged: (p) {
                  final slot = _slot;
                  ref
                      .read(buildPlanProvider.notifier)
                      .save(p, characterId: slot);
                  // El del líder lo manda `build_feed`; el de un compañero,
                  // acá (su condición `Build` del filtro).
                  if (slot != null) {
                    c.setMemberWants(
                        view.actorId,
                        buildWantsOf(ref.read(buildPlanRulesProvider), p, prof,
                            stash: stashWeapons(c.stash)));
                  }
                },
              )),
      // El visor del árbol ocupa todo el alto que queda debajo de su fila
      // de arriba (puntos, reinicio, buscador y zoom); con muy poco alto,
      // un visor mínimo que se desplaza.
      CharacterTab.tree => LayoutBuilder(
          builder: (context, box) => box.maxHeight >= 330
              ? _tree(null)
              : SingleChildScrollView(child: _tree(240))),
      // Bestiario de la cuenta (docs/specs/bestiary.md § 4).
      CharacterTab.bestiary => Consumer(
          builder: (context, ref, _) => BestiaryView(
                key: const ValueKey('bestiary-view'),
                bestiary: view.bestiary ?? BestiaryProgress.empty,
                sprites: ref.watch(gameSpritesProvider).valueOrNull,
              )),
      // Hazañas de la cuenta (docs/specs/achievements.md § 7): las del
      // perfil de sesión, que el host mantiene al día.
      CharacterTab.achievements => AchievementsView(
          key: const ValueKey('achievements-view'),
          progress: prof.achievements),
    };

    final closeButton = view.mode == SessionMode.prep
        ? PanelButton('< VOLVER A PREPARACIÓN',
            reason: must ? 'Reparte tus puntos' : null, onPressed: close)
        : PanelButton('CERRAR [ESC]',
            reason: must ? 'Reparte tus puntos' : null, onPressed: close);
    final isAttr = tab == CharacterTab.attributes;
    final treePts = UnusedPoints.of(prof, rules).tree;
    final confirmReason = guards.allocate(prof, _alloc);
    // Barra de herramientas de ATRIBUTOS (design_system.md § 4) y pie del
    // marco, armados por datos (editor_layout.md § 6).
    final slots = <String, DsSlotBuilder>{
      CharacterLayout.points: (_) => !isAttr
          ? null
          : Text('Puntos: $left',
              key: const ValueKey('attr-points'),
              style: DsText.body(left > 0 ? DsColors.reward : DsColors.text)),
      CharacterLayout.respec: (_) => !isAttr || !guards.showRespec
          ? null
          : DsButton(
              ProgressionRules.freeRespec
                  ? 'REINICIAR PUNTOS (GRATIS)'
                  : 'REINICIAR PUNTOS',
              key: const ValueKey('respec'),
              kind: DsButtonKind.ghost,
              size: DsButtonSize.compact,
              tooltip: guards.respec(),
              onPressed: guards.respec() != null
                  ? null
                  : () {
                      if (c.respec()) setState(_alloc.clear);
                    }),
      CharacterLayout.undo: (_) => !isAttr
          ? null
          : DsButton('DESHACER',
              key: const ValueKey('undo-points'),
              size: DsButtonSize.compact,
              onPressed:
                  _allocSum == 0 ? null : () => setState(_alloc.clear)),
      CharacterLayout.confirm: (_) => !isAttr
          ? null
          : DsButton('CONFIRMAR PUNTOS',
              key: const ValueKey('confirm-points'),
              kind: DsButtonKind.primary,
              size: DsButtonSize.compact,
              tooltip: confirmReason,
              onPressed: confirmReason == null ? _confirm : null),
      CharacterLayout.reason: (_) => !isAttr || confirmReason == null
          ? null
          : Text(confirmReason,
              key: const ValueKey('confirm-reason'), style: DsText.detail()),
      CharacterLayout.close: (_) => closeButton,
    };
    Widget host(Widget Function(DsRegions r) frame) => DsLayoutHost(
        spec: CharacterLayout.spec,
        doc: widget.layout,
        hooks: widget.layoutHooks,
        slots: slots,
        frame: (context, box, r) => frame(r));
    final attrBar = host((r) => r.isEmpty('toolbar')
        ? const SizedBox.shrink()
        : Padding(
            padding: EdgeInsets.only(bottom: DsSpace.sm),
            child: r.region('toolbar')));

    // Q / E, Ctrl+Tab y 1-5 cambian de pestaña (menu_focus.dart); no
    // mientras hay que repartir.
    return PartyMemberKeys(
      view: view,
      controller: c,
      child: MenuTabKeys(
        count: CharacterTab.values.length,
        index: tab.index,
        enabled: !must,
        onChanged: (i) => setState(() => _tab = CharacterTab.values[i]),
        child: PanelFrame(
          title: must
              ? '¡SUBISTE A NIVEL ${prof.level}! 1 punto de atributo (+3) y 1 de árbol'
              : 'PERSONAJE',
          width: 1000,
          fill: true,
          // La ayuda de la pestaña (antes una línea fija arriba del
          // contenido) vive en el "?" (design_system.md § 2.4).
          help: '${switch (tab) {
            CharacterTab.filter => kFilterHelp,
            CharacterTab.ults => UltRepertoireView.help,
            CharacterTab.build => BuildPlannerView.help,
            CharacterTab.bestiary => BestiaryView.help,
            CharacterTab.achievements => AchievementsView.help,
            _ => CharacterPanel.help,
          }}<br><br><span class="k">${tab.label}</span>: ${protoEsc(tab.hint)}',
          onClose: close,
          // Flexible: con texto grande baja de línea en vez de desbordar.
          // Jerarquía por color: nombre en Cuerpo, clase en Subtítulo,
          // maestría y XP en Detalle (sin negritas).
          titleTrailing: Flexible(
              child: Text.rich(
                  key: const ValueKey('char-title-info'),
                  TextSpan(children: [
                    TextSpan(
                        text: retroText(profileTitle(prof)),
                        style: DsText.body(DsColors.textPrimary)),
                    TextSpan(
                        text: '  ${retroText(cls)} Lv${prof.level}',
                        style: DsText.body(DsColors.textSubtitle)),
                    if (prof.level >= ProgressionRules.maxLevel)
                      TextSpan(
                          text: '  ${retroText(masteryText(prof))}',
                          style: DsText.detail()),
                    // XP para subir (v0.8.6).
                    if (xpProgress(prof) != null)
                      TextSpan(
                          text: '  ${retroText(xpProgressText(prof))}',
                          style: DsText.detail()),
                  ]))),
          header: must
              ? null
              : PartyMemberBar.header(
                  view,
                  c,
                  DsTabBar(
                    index: tab.index,
                    onChanged: (i) =>
                        setState(() => _tab = CharacterTab.values[i]),
                    // Puntos sin usar (passive_tree_v4.md § 7): insignia
                    // dentro de la pestaña, a la derecha del texto.
                    tabs: [
                      for (final t in CharacterTab.values)
                        DsTab(t.label,
                            key: ValueKey('tab-${t.index}'),
                            badgeKey: ValueKey('tab-badge-${t.index}'),
                            badge: switch (t) {
                              CharacterTab.attributes when left > 0 => '$left',
                              CharacterTab.tree when treePts > 0 => '$treePts',
                              // ULT aprendidas sin mirar (ultimates_v2.md § 2.1).
                              CharacterTab.ults when prof.ultNew.isNotEmpty =>
                                'NUEVA',
                              _ => null,
                            }),
                    ],
                  )),
          actions: [host((r) => r.region('actions'))],
          // Con muy poco alto la barra se desplaza (hasta la mitad) en vez
          // de desbordar.
          child: LayoutBuilder(
            builder: (context, box) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: box.maxHeight / 2),
                    child: SingleChildScrollView(child: attrBar)),
                Expanded(child: body),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------- atributos ----------------

  /// ATRIBUTOS (design_system.md): filas de una línea a la izquierda,
  /// vista previa a la derecha; secciones con DsSectionHeader, sin cajas
  /// anidadas ni párrafos (la explicación está en el "?").
  Widget _attributes() {
    final view = widget.view;
    final prof = view.actor!.profile;
    final c = widget.controller;
    final rules = c.engine.progression;
    final guards = ShopContext(view, c).guards;
    final left = prof.points - _allocSum;

    final left0 = SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Con plan de build: el objetivo de cada atributo y a cuál
                // le faltan puntos (build_planner.md § 4.1).
                Consumer(builder: (context, ref, _) {
                  final plan = ref.watch(buildPlanProvider).planFor(_slot);
                  final want = [
                    for (final a in Attribute.values)
                      if ((plan.attributes[a] ?? 0) > prof.attributes[a])
                        kAttributeInfo[a]!.$1,
                  ];
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DsSectionHeader('ATRIBUTOS',
                          trailing: want.isNotEmpty && prof.points > 0
                              ? Text(
                                  retroText('★ Según tu build: '
                                      '${want.join(', ')}'),
                                  key: const ValueKey('build-attr-hint'),
                                  style: DsText.detail(kPlanColor))
                              : null),
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
                  Padding(
                    padding: EdgeInsets.only(top: DsSpace.sm),
                    child: Text(
                        'El equipo sigue cuando todos confirmen sus puntos.',
                        style: DsText.body(DsColors.warning)),
                  ),
                // Qué subir según el arma y el árbol (build_planner.md § 8).
                Consumer(
                    builder: (context, ref, _) =>
                        _advice(ref.watch(buildPlanProvider).planFor(_slot))),
                DsSectionHeader('CLASE',
                    trailing: Text(
                        view.mode == SessionMode.lobby
                            ? 'Cambiarla reinicia atributos y árbol'
                            : 'Solo en el lobby',
                        style: DsText.detail())),
                Wrap(
                  spacing: DsSpace.sm,
                  runSpacing: DsSpace.sm,
                  children: [
                    for (final cl in rules.catalog.classes.values)
                      if (FeatureFlags.instance.isCharacterAllowed(cl.id))
                        DsButton(cl.name,
                            key: ValueKey('class-${cl.id}'),
                            size: DsButtonSize.compact,
                            selected: cl.id == prof.classId,
                            tooltip: cl.id == prof.classId
                                ? null
                                : guards.changeClass(prof, cl.id),
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
                // Invocador (summoner.md § 8).
                GrimoireSection(rules: rules, profile: prof),
                if (prof.classId == 'paladin') ...[
                  const DsSectionHeader('RASGOS DE PALADÍN'),
                  const DsFold(
                    label: 'VER RASGOS',
                    openLabel: 'OCULTAR',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Básico: 3% aturdir · habilidades según el arma'),
                        Text('Débil a perforante (×1.5) y a estados (+1)'),
                        Text('Aura, Fortaleza y Protección: kit del Guardián'),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
    // Con poco ancho la vista previa va debajo (nunca desborda).
    return LayoutBuilder(builder: (context, box) {
      final side = RetroType.width(context, 380);
      if (box.maxWidth < side * 2 + DsSpace.lg) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(flex: 3, child: left0),
            SizedBox(height: DsSpace.sm),
            Expanded(flex: 2, child: _preview()),
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: left0),
          SizedBox(width: DsSpace.lg),
          SizedBox(width: side, child: _preview()),
        ],
      );
    });
  }

  /// `previewOf`: stats con el reparto pendiente.
  Widget _preview() {
    final prof = widget.view.actor!.profile;
    final rules = widget.controller.engine.progression;
    final now = rules.derivedStats(prof);
    final next = _allocSum == 0 ? now : rules.previewAllocation(prof, _alloc);
    final w = rules.equippedWeapon(prof);
    final pending = [
      for (final a in Attribute.values)
        if ((_alloc[a] ?? 0) > 0)
          '+${_alloc[a]! * kAttrPerPoint} ${kAttributeInfo[a]!.$1}',
    ];
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const DsSectionHeader('VISTA PREVIA'),
          DefaultTextStyle.merge(
            style: DsText.body(),
            child: CharacterStatRows(now: now, next: next, weight: w.weight),
          ),
          const DsSectionHeader('PENDIENTE'),
          ProtoText(
            pending.isEmpty
                ? protoColor(DsColors.textSecondary, 'Sin cambios pendientes')
                : 'Pendiente: ${protoColor(ProtoColors.green, pending.join(' '))}',
            key: const ValueKey('pending-points'),
          ),
        ],
      ),
    );
  }

  /// Un atributo en una línea (v0.10.1, design_system.md § 6
  /// DsAttributeRow): sigla y nombre, valor (+ reparto pendiente), meta
  /// del plan (★), botones − y "+3 VIT"; qué hace y el tope, en el
  /// tooltip. Sin borde: el fondo marca el reparto pendiente.
  Widget _attrRow(Attribute a, int value, int left, {int? target}) {
    final (short, name, desc) = kAttributeInfo[a]!;
    final add = _alloc[a] ?? 0;
    // Tooltip (mouse o foco en - / +): qué cambia en batalla con 1 punto
    // más (battle_impact.dart, tus números reales).
    final prof = widget.view.actor!.profile;
    final rules = widget.controller.engine.progression;
    final now = _allocSum == 0
        ? rules.derivedStats(prof)
        : rules.previewAllocation(prof, _alloc);
    final next = rules.previewAllocation(prof, {..._alloc, a: add + 1});
    final impact =
        battleImpactMarkup(rules, now, next, weapon: rules.equippedItem(prof));
    final big = RetroType.settingFactor(context) >= 1.9;
    // Tope blando (progression_v2.md § 2.2).
    final cap = kAttrSoftCap[a]!;
    final shown = value + add * kAttrPerPoint;
    final over = shown > cap;
    final gain =
        effectiveAttr(a, shown + kAttrPerPoint) - effectiveAttr(a, shown);
    final full = gain >= kAttrPerPoint;
    String num1(double v) =>
        v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);
    // Jerarquía por color: sigla en Cuerpo, nombre en Detalle.
    final nameText = Text.rich(TextSpan(children: [
      TextSpan(text: short, style: DsText.body(DsColors.textPrimary)),
      if (!big) TextSpan(text: '  ${retroText(name)}', style: DsText.detail()),
    ]));
    final valueColor = over ? ProtoColors.orange : DsColors.textPrimary;
    final addText = add > 0
        ? ' ${protoColor(over ? ProtoColors.orange : ProtoColors.green, '+${add * kAttrPerPoint}')}'
        : '';
    final valueText = ProtoText('${protoColor(valueColor, '$value')}$addText',
        key: ValueKey('attr-value-${a.name}'));
    final targetText = target == null
        ? null
        : Text('★ $shown/$target',
            key: ValueKey('build-attr-${a.name}'),
            style: DsText.detail(
                shown >= target ? ProtoColors.green : kPlanColor));
    return RetroTooltip(
        message: '+$kAttrPerPoint ${retroText(name)}: ${retroText(desc)}'
            '<br>Tope $cap: pasado el tope rinde ½'
            '${full ? '' : '<br>Pasaste el tope $cap: rinde +${num1(gain)}'}'
            '${impact == null ? '' : '<br>$impact'}',
        child: Container(
          key: ValueKey('attr-row-${a.name}'),
          padding: EdgeInsets.symmetric(
              horizontal: DsSpace.md, vertical: DsSpace.xs),
          // Siempre con color (transparente): cambiar el árbol perdería el foco.
          color: add > 0
              ? DsColors.hover.withValues(alpha: 0.5)
              : Colors.transparent,
          // Con texto ENORME o poco ancho: sin anchos fijos; la sigla,
          // el valor y la ★ en un wrap y los botones a la derecha (o
          // debajo si no entran). Nunca desborda.
          child: LayoutBuilder(builder: (context, box) {
            final fixed = RetroType.em(context, 15, size: RetroType.body) +
                RetroType.em(context, 7, size: RetroType.small) +
                (targetText == null
                    ? 0
                    : RetroType.em(context, 9, size: RetroType.small));
            final buttons = Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                runSpacing: DsSpace.xs,
                children: [
                DsButton.icon(
                    Text('-',
                        style: DsText.subtitle(add > 0
                            ? DsColors.textPrimary
                            : DsColors.textDisabled)),
                    key: ValueKey('dec-${a.name}'),
                    tooltip: add > 0
                        ? 'Quitar $short (+$kAttrPerPoint sin confirmar)'
                        : 'Solo quita puntos sin confirmar. Para reasignar '
                            'los confirmados: REINICIAR PUNTOS'
                            '${ProgressionRules.freeRespec ? ' (gratis)' : ''}',
                    size: DsButtonSize.compact,
                    onPressed: add > 0
                        ? () => setState(() => _alloc[a] = add - 1)
                        : null),
                SizedBox(width: DsSpace.xs),
                DsButton(
                    full
                        ? '+$kAttrPerPoint $short'
                        : '+$kAttrPerPoint $short → +${num1(gain)}',
                    key: ValueKey('inc-${a.name}'),
                    size: DsButtonSize.compact,
                    accent: full ? null : DsColors.warning,
                    onPressed: left > 0
                        ? () => setState(() => _alloc[a] = add + 1)
                        : null),
            ]);
            if (big || box.maxWidth < fixed + RetroType.width(context, 200)) {
              return Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                runSpacing: DsSpace.xs,
                children: [
                  Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      nameText,
                      valueText,
                      if (targetText != null) targetText
                    ],
                  ),
                  buttons,
                ],
              );
            }
            return Row(
              children: [
                SizedBox(
                    width: RetroType.em(context, 15, size: RetroType.body),
                    child: nameText),
                SizedBox(
                    width: RetroType.em(context, 7, size: RetroType.small),
                    child: valueText),
                if (targetText != null)
                  SizedBox(
                      width: RetroType.em(context, 9, size: RetroType.small),
                      child: targetText),
                const Spacer(),
                buttons,
              ],
            );
          }),
        ));
  }

  /// SUGERENCIA: el reparto del asesor para los puntos libres del miembro
  /// activo en una línea, las razones plegadas (DsFold) y APLICAR (pide
  /// confirmar; descarta el reparto pendiente).
  Widget _advice(BuildPlan plan) {
    final view = widget.view;
    final c = widget.controller;
    final prof = view.actor!.profile;
    final s = AttributeAdvisor(c.engine.progression).recommend(prof, plan);
    if (s.isEmpty) return const SizedBox.shrink();
    final add = AttributeAdvisor.allocation(s);
    final split = AttributeAdvisor.split(s);
    final reason = ShopContext(view, c).guards.allocate(prof, add);
    Future<void> apply() async {
      final ok = await showBuildPicker<bool>(context, '¿APLICAR SUGERENCIA?', [
        PickOption(
            true,
            'Sí, repartir: $split',
            'Se gastan ${prof.points} puntos de ${prof.name}'
                '${_allocSum > 0 ? '; se descarta el reparto pendiente' : ''}.',
            key: 'advice-yes'),
        const PickOption(false, 'No', null, key: 'advice-no'),
      ]);
      if (ok != true || !mounted) return;
      if (c.allocate(add)) setState(_alloc.clear);
    }

    return Column(
      key: const ValueKey('attr-advice'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DsSectionHeader('SUGERENCIA',
            trailing: Text(
                plan.isEmpty ? 'según tu arma y tu árbol' : 'según tu build',
                style: DsText.detail())),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: DsSpace.md),
          child: Wrap(
              spacing: DsSpace.sm,
              runSpacing: DsSpace.xs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(retroText(split),
                    key: const ValueKey('attr-advice-split'),
                    style: DsText.body(kPlanColor)),
                DsButton('APLICAR SUGERENCIA',
                    key: const ValueKey('apply-advice'),
                    size: DsButtonSize.compact,
                    accent: kPlanColor,
                    tooltip: reason,
                    onPressed: reason == null ? apply : null),
              ]),
        ),
        Padding(
          padding: EdgeInsets.only(left: DsSpace.xs),
          child: DsFold(
            label: 'POR QUÉ',
            openLabel: 'OCULTAR',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final x in s)
                  Text(
                      retroText(
                          '${x.short} +${x.points}: ${x.reasons.join(' · ')}'),
                      key: ValueKey('attr-advice-${x.attribute.name}'),
                      style: DsText.detail()),
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _confirm() {
    final add = {
      for (final e in _alloc.entries)
        if (e.value > 0) e.key: e.value,
    };
    if (widget.controller.allocate(add)) setState(_alloc.clear);
  }

  // ---------------- árbol ----------------

  Widget _tree(double? height) {
    final view = widget.view;
    final c = widget.controller;
    final p = view.actor!.profile;
    final guards = ShopContext(view, c).guards;
    return Consumer(
      builder: (context, ref, _) => PassiveTreeView(
        planned: ref.watch(buildPlanProvider).planFor(_slot).treeNodes.toSet(),
        planOrder: BuildGuideRules(c.engine.progression)
            .treeOrder(ref.watch(buildPlanProvider).planFor(_slot), p),
        rules: c.engine.progression.treeRules,
        profile: p,
        inBattle: view.mode == SessionMode.battle,
        onTake: c.takeNode,
        onTakePath: c.takeNodes,
        onUntake: c.untakeNode,
        untakeReason: (id) => guards.untakeNode(p, id),
        onChooseMilestone: c.chooseMilestone,
        onMark: (id) {
          final slot = _slot;
          final plan = ref.read(buildPlanProvider).planFor(slot);
          ref
              .read(buildPlanProvider.notifier)
              .save(plan.toggleTreeNode(id), characterId: slot);
        },
        showReset: guards.showRespec,
        resetLabel: ProgressionRules.freeRespec
            ? 'REINICIAR ÁRBOL (GRATIS)'
            : 'REINICIAR ÁRBOL',
        resetReason: guards.resetTree(p),
        onReset: () => _resetTree(p),
        height: height,
        showHelp: false,
      ),
    );
  }

  /// REINICIAR ÁRBOL: con hitos elegidos pide confirmar (vuelven a
  /// quedar pendientes; progression_v2.md § 6).
  Future<void> _resetTree(PlayerProfile p) async {
    final c = widget.controller;
    if (p.milestone10 == null && p.milestone20 == null) {
      c.resetTree();
      return;
    }
    final ok = await showBuildPicker<bool>(context, '¿REINICIAR ÁRBOL?', [
      const PickOption(true, 'Sí, reiniciar',
          'También podés volver a elegir tus hitos (nivel 10 y 20).',
          key: 'tree-reset-yes'),
    ]);
    if (ok == true && mounted) c.resetTree();
  }
}
