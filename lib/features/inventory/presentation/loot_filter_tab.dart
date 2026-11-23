import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/design/design.dart';
import '../../../app/theme/retro_text.dart';
import '../../../app/theme/retro_theme.dart';
import '../../../core/i18n/i18n_providers.dart';
import '../../../game_engine/models/build_wants.dart';
import '../../../game_engine/models/item.dart';
import '../../../game_engine/models/loot.dart';
import '../../../game_engine/models/loot_filter.dart';
import '../../../game_engine/models/player_profile.dart';
import '../../../game_engine/rules/loot_filter_rules.dart';
import '../../../game_engine/rules/progression_rules.dart';
import '../../build_planner/domain/build_wants_of.dart';
import '../../build_planner/presentation/build_fit_badge.dart'
    show buildPlanRulesProvider, kPlanColor;
import '../../build_planner/presentation/build_plan_providers.dart';
import '../domain/filter_build_snippets.dart';
import '../domain/filter_quick.dart';
import '../domain/item_text.dart';
import '../domain/shop_guards.dart';
import 'item_widgets.dart';
import 'shop_sections.dart';

/// Ayuda `[?]` de la pestaña, con la gramática corta del filtro (loot.md
/// § 13). The filter keywords (Mostrar, Rareza…) are the parser's own
/// words, so every language keeps them as is.
String filterHelp(Strings s) => '${s.t('ui.inventory.filter.help', {
      'star': '★',
      'cross': '✕'
    })}<br><br>${s.t('ui.inventory.filter.grammar', {
      'star': '★',
      'dash': '–',
      'ellipsis': '…'
    })}';

/// Gramática corta del filtro (loot.md § 13), para la ayuda.
/// es-AR only: kept for callers outside this feature; use [filterHelp].
const kFilterGrammar = '<b>Mostrar</b> u <b>Ocultar</b> [# nombre] y debajo, '
    'con sangría, condiciones y acciones.<br>'
    '<span class="k">Condiciones</span>: Rareza [op] Común/Mágico/Raro/Épico/'
    'Legendario · Tipo espada lanza… · Base id · Clase guerrero · '
    'NivelObjeto &lt; 10 · NivelRelativo &lt;= -6 · Mods &gt;= 3 · TieneMod '
    'feroz &lt;= 2 · Pasiva [Si/No] · Material esquirla/cristal/prisma · '
    'Objeto Arma/Material/Pocion · Utilizable [Si/No] · '
    'Peso Ligera/Media/Pesada · '
    'Build [Base/Mod/Pasiva/Habilidad] o Build No (coincide con tu plan de '
    'build, ★).<br>'
    '<span class="k">op</span>: = != &lt; &lt;= &gt; &gt;=<br>'
    '<span class="k">Acciones</span>: Color R G B [A] · Borde R G B · Fondo R G '
    'B [A] · Tamaño 18–45 · Sonido alerta/campana/gema/legendario/material/'
    'suave · Icono circulo/estrella/triangulo/cuadrado/diamante [color].<br>'
    'Gana la primera regla que coincide. # empieza un comentario.';

/// Ayuda `[?]` de la pestaña (es-AR only, for callers outside this
/// feature that have no [Strings] yet; use [filterHelp]).
const kFilterHelp = '<b>Filtro de loot</b><br>'
    '<span class="k">CASILLAS</span>: OCULTAR RÁPIDO marca lo que no querés '
    'ver en el mapa (por tipo, peso, uso y nivel nunca se ocultan Épicas ni '
    'Legendarias; la excepción ★ va primero y le gana a todo). TUS REGLAS, en '
    'orden de arriba a abajo: la casilla apaga la regla sin borrarla (queda '
    'en el texto con #OFF) y ✕ la borra.<br>'
    '<span class="k">★ MI BUILD</span>: la condición Build coincide con lo '
    'que pide tu plan (pestaña BUILD); en el mapa lleva ★.<br>'
    '<span class="k">VISTA PREVIA</span>: cómo se verían objetos de muestra '
    'de tu nivel.<br><br>$kFilterGrammar';

/// Objetos de muestra para la vista previa del filtro (nivel [level]).
List<LootDrop> filterSamples(int level) {
  final low = math.max(1, level - 8);
  return [
    LootDrop.item(ItemInstance.common('m1', 'espada_bronce', itemLevel: low)),
    LootDrop.item(ItemInstance(
        uid: 'm2',
        baseId: 'arco_corto',
        rarity: Rarity.magico,
        itemLevel: level,
        affixes: const [AffixRoll('certero', 5, 3)])),
    LootDrop.item(ItemInstance(
        uid: 'm3',
        baseId: 'baculo_fuego',
        rarity: Rarity.raro,
        itemLevel: level,
        name: 'Eco Voraz',
        affixes: const [
          AffixRoll('arcano', 5, 8),
          AffixRoll('del_sabio', 5, 3),
          AffixRoll('de_la_vida', 5, 12),
        ])),
    LootDrop.item(ItemInstance(
        uid: 'm4',
        baseId: 'espada_templada',
        rarity: Rarity.epico,
        itemLevel: math.max(14, level),
        name: 'Filo del Alba',
        passiveId: 'impetu',
        affixes: const [
          AffixRoll('feroz', 4, 12),
          AffixRoll('certero', 4, 5),
          AffixRoll('del_toro', 4, 6),
          AffixRoll('de_la_vida', 4, 20),
          AffixRoll('del_vampiro', 4, 2),
        ])),
    LootDrop.item(ItemInstance(
        uid: 'm5',
        baseId: 'espada_templada',
        rarity: Rarity.legendario,
        itemLevel: math.max(14, level),
        uniqueId: 'juramentoAlba',
        passiveId: 'albaImplacable',
        affixes: const [
          AffixRoll('feroz', 0, 25),
          AffixRoll('certero', 0, 6),
          AffixRoll('del_oso', 4, 6),
        ])),
    const LootDrop.stack(StackKind.prisma, 1),
  ];
}

/// Pestaña FILTRO del personaje: vista CASILLAS (OCULTAR RÁPIDO y la
/// lista de reglas con prender / apagar / borrar) o TEXTO (el editor),
/// las dos sobre el mismo texto; validación por línea, vista previa sobre
/// objetos de muestra, guardar y restaurar. Ver docs/specs/panels.md
/// § "Filtro de loot".
class LootFilterTab extends ConsumerStatefulWidget {
  const LootFilterTab({super.key, required this.shop});

  final ShopContext shop;

  @override
  ConsumerState<LootFilterTab> createState() => _LootFilterTabState();
}

class _LootFilterTabState extends ConsumerState<LootFilterTab> {
  late final _text = TextEditingController(text: _savedText);
  final _focus = FocusNode(debugLabel: 'loot-filter');

  PlayerProfile get _p => widget.shop.profile;
  String get _savedText => _p.lootFilter ?? LootFilterRules.defaultText;

  /// Qué partes del plan pide la condición `Build` que se agrega (vacío =
  /// cualquier meta).
  final _buildKinds = <BuildMatch>{};

  /// `BuildMejora` en vez de `Build` (build_planner_v2.md § 1.4).
  bool _buildUpgrade = false;

  /// Vista TEXTO (`true`) o CASILLAS (`false`, la de entrada).
  var _textView = false;

  late final _options = quickOptions(widget.shop.rules.catalog);

  void _setText((String, int) r) {
    _text.value = TextEditingValue(
        text: r.$1, selection: TextSelection.collapsed(offset: r.$2));
  }

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
    // Mientras se escribe, el jugador no se mueve (como en el chat).
    _focus.addListener(() {
      final c = widget.shop.controller;
      if (c.mounted) c.typing = _focus.hasFocus;
    });
  }

  @override
  void dispose() {
    final c = widget.shop.controller;
    if (_focus.hasFocus && c.mounted) c.typing = false;
    _focus.dispose();
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shop = widget.shop;
    final rules = shop.rules;
    final p = _p;
    final fr = LootFilterRules(catalog: rules.catalog);
    final parsed = fr.parse(_text.text);
    final reason = ShopGuards.saveFilter(
        _text.text, p.lootFilter, parsed.errors.length,
        defaultText: LootFilterRules.defaultText);
    final f = parsed.filter;

    final doc = FilterDoc.parse(_text.text, _options, catalog: rules.catalog);

    // Barra de herramientas (design_system.md § 4): vista, estado y
    // acciones en una fila; GUARDAR es la principal.
    final s = ref.strings;
    final status = parsed.ok
        ? s.t('ui.inventory.filter.status_ok', {
            'n': f.rules.length,
            'default': p.lootFilter == null ? 'yes' : 'no'
          })
        : '${parsed.errors.first}'
            '${parsed.errors.length > 1 ? ' (+${parsed.errors.length - 1})' : ''}';
    final statusText = KeyedSubtree(
      key: const ValueKey('filter-status'),
      child: Text(retroText(status),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: DsText.detail(parsed.ok ? DsColors.success : DsColors.danger)),
    );
    final toolbar = Padding(
      padding: EdgeInsets.only(bottom: DsSpace.sm),
      child: Wrap(
        spacing: DsSpace.sm,
        runSpacing: DsSpace.xs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          DsButton(s.t('ui.inventory.filter.view_checks'),
              key: const ValueKey('filter-view-checks'),
              size: DsButtonSize.compact,
              selected: !_textView,
              onPressed: () => setState(() => _textView = false)),
          DsButton(s.t('ui.inventory.filter.view_text'),
              key: const ValueKey('filter-view-text'),
              size: DsButtonSize.compact,
              selected: _textView,
              onPressed: () => setState(() => _textView = true)),
          SizedBox(width: DsSpace.md),
          parsed.ok
              ? statusText
              : Tooltip(message: parsed.errors.join('\n'), child: statusText),
          SizedBox(width: DsSpace.md),
          DsButton(s.t('ui.inventory.filter.restore_default'),
              key: const ValueKey('filter-default'),
              kind: DsButtonKind.ghost,
              size: DsButtonSize.compact,
              onPressed: _text.text == LootFilterRules.defaultText
                  ? null
                  : () => _text.text = LootFilterRules.defaultText),
          DsButton(s.t('ui.inventory.filter.revert'),
              key: const ValueKey('filter-revert'),
              size: DsButtonSize.compact,
              onPressed: _text.text == _savedText
                  ? null
                  : () => _text.text = _savedText),
          DsButton(s.t('ui.inventory.filter.save'),
              key: const ValueKey('filter-save'),
              kind: DsButtonKind.primary,
              size: DsButtonSize.compact,
              tooltip: reason,
              onPressed: reason != null
                  ? null
                  : () {
                      final t = _text.text;
                      shop.controller.setLootFilter(
                          t == LootFilterRules.defaultText ? null : t);
                      setState(() {});
                    }),
        ],
      ),
    );

    // Con poco alto (texto ENORME) el editor no entra: alto fijo y todo
    // scrollea.
    Widget editorFor(bool tight) {
      final Widget view = _textView
          ? TextField(
              key: const ValueKey('filter-text'),
              controller: _text,
              focusNode: _focus,
              maxLines: null,
              expands: true,
              keyboardType: TextInputType.multiline,
              textAlignVertical: TextAlignVertical.top,
              style: DsText.body(DsColors.textPrimary).copyWith(height: 1.4),
              decoration: InputDecoration(
                  contentPadding: EdgeInsets.all(DsSpace.sm), isDense: true),
            )
          : _checksView(doc);
      return tight
          ? SizedBox(height: 260, child: view)
          : SizedBox.expand(child: view);
    }

    final editor = LayoutBuilder(
        builder: (context, c) => c.maxHeight < RetroType.width(context, 260)
            ? SingleChildScrollView(child: editorFor(true))
            : editorFor(false));

    // El plan del miembro activo: la vista previa evalúa `Build` igual
    // que el host.
    final wants = buildWantsOf(
        ref.watch(buildPlanRulesProvider),
        ref
            .watch(buildPlanProvider)
            .planFor(shop.controller.slotOf(shop.view.actorId)),
        p,
        stash: stashWeapons(shop.controller.stash));
    final ctx = FilterContext(
        level: p.level,
        attributes: p.attributes,
        classId: p.classId,
        wants: wants);
    final side = SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ..._buildSection(wants),
          DsSectionHeader(
              s.t('ui.inventory.filter.preview_title', {'level': p.level})),
          for (final (i, d) in filterSamples(p.level).indexed)
            _sample(rules, fr, f, d, ctx, i),
        ],
      ),
    );

    return LayoutBuilder(
        builder: (context, box) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Con texto ENORME la barra baja de línea: tope del 40 % del alto.
                ConstrainedBox(
                  constraints: BoxConstraints(
                      maxHeight: box.maxHeight.isFinite
                          ? box.maxHeight * 0.4
                          : double.infinity),
                  child: SingleChildScrollView(child: toolbar),
                ),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: editor),
                      SizedBox(width: DsSpace.md),
                      SizedBox(width: 400, child: side),
                    ],
                  ),
                ),
              ],
            ));
  }

  /// Vista CASILLAS: OCULTAR RÁPIDO (casillas en grilla que agregan /
  /// sacan reglas `# rápido: …`) y TUS REGLAS (una fila por regla con
  /// prender / apagar y ✕). Todo cambia el mismo texto (filter_quick.dart).
  /// La explicación está en el "?" ([kFilterHelp]).
  Widget _checksView(FilterDoc doc) {
    final checked = doc.checked;
    final s = ref.read(stringsProvider);
    Widget group(QuickGroup g) {
      final opts = [
        for (final o in _options)
          if (o.group == g) o
      ];
      final label = Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Text(retroText(g.label), style: DsText.detail()),
      );
      final checks = Wrap(spacing: DsSpace.md, children: [
        for (final o in opts)
          FilterCheck(
            key: ValueKey('filter-quick-${o.id}'),
            label: o.label,
            value: checked.contains(o.id),
            color: g == QuickGroup.excepcion ? kPlanColor : null,
            onChanged: (on) => _setText((doc.setQuick(o.id, on), 0)),
          ),
      ]);
      // Grilla: rótulo a la izquierda; si no entra (texto grande), arriba.
      return Padding(
        padding: EdgeInsets.only(bottom: DsSpace.xs),
        child: LayoutBuilder(builder: (context, c) {
          final lw = RetroType.width(context, 150);
          if (c.maxWidth < lw * 2.5) {
            return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [label, checks]);
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: lw, child: label),
              Expanded(child: checks),
            ],
          );
        }),
      );
    }

    return SingleChildScrollView(
      key: const ValueKey('filter-checks'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DsSectionHeader(s.t('ui.inventory.filter.quick_hide')),
          for (final g in QuickGroup.values) group(g),
          DsSectionHeader(
              s.t('ui.inventory.filter.your_rules', {'n': doc.blocks.length}),
              key: const ValueKey('filter-rules-title')),
          if (doc.blocks.isEmpty)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: DsSpace.md),
              child: Text(retroText(s.t('ui.inventory.filter.no_rules')),
                  style: DsText.detail()),
            ),
          for (final (i, b) in doc.blocks.indexed) _ruleRow(doc, i, b),
        ],
      ),
    );
  }

  /// Una regla en una línea: casilla, verbo (verde / rojo), nombre y
  /// condiciones; el texto completo en el tooltip.
  Widget _ruleRow(FilterDoc doc, int i, FilterBlock b) {
    final on = b.enabled;
    final name = FilterDoc.summary(b);
    final conds = FilterDoc.conditionsText(b);
    final s = ref.read(stringsProvider);
    // El verbo da el color de la fila: verde Mostrar, rojo Ocultar.
    return DsListRow(
      key: ValueKey('filter-rule-$i'),
      leading: FilterCheck(
        key: ValueKey('filter-rule-on-$i'),
        value: on,
        onChanged: (v) => _setText((doc.setEnabled(i, v), 0)),
      ),
      title: retroText(s.t('ui.inventory.filter.rule_title',
          {'verb': b.show ? 'show' : 'hide', 'name': name})),
      titleColor: b.show ? DsColors.success : DsColors.danger,
      enabled: on,
      detail: b.errors.isNotEmpty
          ? retroText(s.t('ui.inventory.filter.rule_errors'))
          : name != conds
              ? retroText(conds)
              : null,
      detailColor: b.errors.isNotEmpty ? DsColors.danger : null,
      onTap: () => _setText((doc.setEnabled(i, !on), 0)),
      tooltip: DsTooltipCard(
        title: retroText(name),
        children: [
          Text(b.text.trimRight(), style: DsText.detail()),
        ],
      ),
      // Fantasma (sin caja hasta el hover): la fila no crece por el botón.
      trailing: DsButton('×',
          key: ValueKey('filter-rule-del-$i'),
          kind: DsButtonKind.ghost,
          size: DsButtonSize.compact,
          accent: DsColors.danger,
          tooltip: s.t('ui.inventory.filter.delete_rule'),
          onPressed: () => _setText((doc.remove(i), 0))),
    );
  }

  /// Sección "★ MI BUILD" (condición `Build`, loot.md § 13): elegir qué
  /// parte del plan y agregarla a la regla del cursor o como una regla
  /// nueva que resalta / oculta.
  List<Widget> _buildSection(BuildWants wants) {
    final s = ref.read(stringsProvider);
    final bases = wants.weaponTypes.length + wants.weaponBases.length;
    final summary = wants.isEmpty
        ? s.t('ui.inventory.filter.wants.no_plan')
        : s.t('ui.inventory.filter.wants.summary', {
            'parts': [
              if (bases > 0) s.t('ui.inventory.filter.wants.bases', {'n': bases}),
              if (wants.mods.isNotEmpty)
                s.t('ui.inventory.filter.wants.mods', {'n': wants.mods.length}),
              if (wants.weaponPassive != null) s.t('ui.inventory.filter.wants.passive'),
              if (wants.skills.isNotEmpty)
                s.t('ui.inventory.filter.wants.skills', {'n': wants.skills.length}),
              if (wants.target != null)
                s.t('ui.inventory.filter.wants.target', {'pct': wants.best}),
            ].join(' · ')
          });
    Widget kind(String label, BuildMatch? k) {
      final on = k == null ? _buildKinds.isEmpty : _buildKinds.contains(k);
      return DsButton(label,
          key: ValueKey('filter-build-kind-${k?.name ?? 'any'}'),
          size: DsButtonSize.compact,
          selected: on && !_buildUpgrade,
          onPressed: () => setState(() {
                _buildUpgrade = false;
                if (k == null) {
                  _buildKinds.clear();
                } else if (!_buildKinds.remove(k)) {
                  _buildKinds.add(k);
                }
              }));
    }

    final cond =
        FilterBuildSnippets.line(_buildKinds, upgrade: _buildUpgrade);
    return [
      DsSectionHeader(
          s.t('ui.inventory.filter.build.title', {'star': '★'}),
          key: const ValueKey('filter-build-title')),
      Text(retroText(summary),
          key: const ValueKey('filter-build-plan'),
          style: DsText.detail(wants.isEmpty ? null : kPlanColor)),
      SizedBox(height: DsSpace.xs),
      Wrap(spacing: DsSpace.xs, runSpacing: DsSpace.xs, children: [
        kind(s.t('ui.inventory.filter.build.any'), null),
        kind(s.t('ui.inventory.filter.build.base'), BuildMatch.base),
        kind(s.t('ui.inventory.filter.build.mod'), BuildMatch.mod),
        kind(s.t('ui.inventory.filter.build.passive'), BuildMatch.pasiva),
        kind(s.t('ui.inventory.filter.build.skill'), BuildMatch.habilidad),
        DsButton(s.t('ui.inventory.filter.build.upgrade_only'),
            key: const ValueKey('filter-build-kind-upgrade'),
            size: DsButtonSize.compact,
            selected: _buildUpgrade,
            tooltip: wants.target == null
                ? s.t('ui.inventory.filter.build.upgrade_no_target')
                : s.t('ui.inventory.filter.build.upgrade_tip'),
            onPressed: () => setState(() => _buildUpgrade = !_buildUpgrade)),
      ]),
      SizedBox(height: DsSpace.xs),
      Text(retroText(s.t('ui.inventory.filter.build.line', {'cond': cond})),
          key: const ValueKey('filter-build-line'),
          style: DsText.body(DsColors.textPrimary)),
      SizedBox(height: DsSpace.xs),
      Wrap(spacing: DsSpace.xs, runSpacing: DsSpace.xs, children: [
        DsButton(s.t('ui.inventory.filter.build.insert'),
            key: const ValueKey('filter-build-insert'),
            size: DsButtonSize.compact,
            tooltip: s.t('ui.inventory.filter.build.insert_tip'),
            onPressed: () => _setText(FilterBuildSnippets.insertCondition(
                _text.text, _text.selection.baseOffset, _buildKinds,
                upgrade: _buildUpgrade))),
        DsButton(s.t('ui.inventory.filter.build.highlight'),
            key: const ValueKey('filter-build-highlight'),
            size: DsButtonSize.compact,
            accent: kPlanColor,
            tooltip: s.t('ui.inventory.filter.build.highlight_tip'),
            onPressed: () => _setText(FilterBuildSnippets.prependRule(
                _text.text,
                FilterBuildSnippets.highlightRule(_buildKinds,
                    upgrade: _buildUpgrade)))),
        DsButton(s.t('ui.inventory.filter.build.hide'),
            key: const ValueKey('filter-build-hide'),
            size: DsButtonSize.compact,
            tooltip: s.t('ui.inventory.filter.build.hide_tip'),
            onPressed: () => _setText(FilterBuildSnippets.prependRule(
                _text.text, FilterBuildSnippets.hideRule))),
      ]),
    ];
  }

  /// Una muestra en una línea: la etiqueta como en el mapa y, al lado, la
  /// regla que la toma.
  Widget _sample(ProgressionRules rules, LootFilterRules fr, LootFilter f,
      LootDrop d, FilterContext ctx, int i) {
    final v = fr.evaluate(f, d, ctx);
    final s = ref.read(stringsProvider);
    final rule = v.ruleIndex == null
        ? s.t('ui.inventory.filter.sample.no_rule')
        : f.rules[v.ruleIndex!].name ??
            s.t('ui.inventory.filter.sample.rule_n', {'n': v.ruleIndex! + 1});
    final st = v.style;
    final extra = [
      if (v.buildMatch)
        s.t('ui.inventory.filter.sample.build', {
          'star': '★',
          'what': [for (final b in v.build) b.label].join(', ')
        }),
      if (v.visible && st.sound != null)
        s.t('ui.inventory.filter.sample.sound', {'sound': st.sound}),
      if (v.visible && st.icon != null)
        s.t('ui.inventory.filter.sample.icon',
            {'shape': st.icon!.shape.name, 'color': st.icon!.color.name}),
    ];
    final it = d.item;
    return Padding(
      key: ValueKey('filter-sample-$i'),
      padding: EdgeInsets.only(bottom: DsSpace.xs),
      child: Row(
        children: [
          Flexible(
            child: LootLabel(
              text: dropLabelText(rules, d),
              verdict: v,
              tooltip: it == null
                  ? stackTooltipMarkup(d.stack!, d.count)
                  : itemTooltipMarkup(rules, it,
                      level: ctx.level, attributes: ctx.attributes),
            ),
          ),
          SizedBox(width: DsSpace.sm),
          Expanded(
            child: Text(
                retroText(
                    '$rule${extra.isEmpty ? '' : ' · ${extra.join(' · ')}'}'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: DsText.detail()),
          ),
        ],
      ),
    );
  }
}

/// Casilla `[x] texto` / `[ ] texto` (marcada en dorado, o en [color]),
/// con hover, foco de teclado y cursor de mano.
class FilterCheck extends StatelessWidget {
  const FilterCheck({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
    this.color,
  });

  final bool value;
  final ValueChanged<bool> onChanged;
  final String? label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final on = color ?? DsColors.selected;
    return DsPressable(
      onTap: () => onChanged(!value),
      builder: (_, s) => Container(
        color: s.hot ? DsColors.hover : Colors.transparent,
        padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 2),
        child: Text.rich(TextSpan(children: [
          TextSpan(
              text: value ? '[x]' : '[ ]',
              style: DsText.body(value ? on : DsColors.textSecondary)),
          if (label != null)
            TextSpan(
                text: retroText(' $label'),
                style: DsText.body(value ? on : DsColors.textPrimary)),
        ])),
      ),
    );
  }
}

/// Para mostrar `FilterStyle` sin regla.
FilterVerdict defaultVerdict(LootDrop d) =>
    FilterVerdict(true, LootFilterRules.defaultStyle(d));
