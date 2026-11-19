import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/panel_frame.dart';
import '../../../app/theme/panel_widgets.dart';
import '../../../app/theme/proto_colors.dart';
import '../../../app/theme/proto_markup.dart';
import '../../../app/theme/retro_text.dart';
import '../../../app/theme/retro_theme.dart';
import '../../../game_engine/models/build_wants.dart';
import '../../../game_engine/models/item.dart';
import '../../../game_engine/models/loot.dart';
import '../../../game_engine/models/loot_filter.dart';
import '../../../game_engine/models/player_profile.dart';
import '../../../game_engine/rules/loot_filter_rules.dart';
import '../../../game_engine/rules/progression_rules.dart';
import '../../build_planner/presentation/build_fit_badge.dart' show kPlanColor;
import '../../build_planner/presentation/build_plan_providers.dart';
import '../domain/filter_build_snippets.dart';
import '../domain/filter_quick.dart';
import '../domain/item_text.dart';
import '../domain/shop_guards.dart';
import 'item_widgets.dart';
import 'shop_sections.dart';

/// Gramática corta del filtro (loot.md § 13), para la ayuda.
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

/// Ayuda `[?]` de la pestaña.
const kFilterHelp = '<b>Filtro de loot</b><br>$kFilterGrammar';

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

    final doc = FilterDoc.parse(_text.text, _options, catalog: rules.catalog);
    final editor = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            PanelButton('CASILLAS',
                key: const ValueKey('filter-view-checks'),
                selected: !_textView,
                onPressed: () => setState(() => _textView = false)),
            PanelButton('TEXTO',
                key: const ValueKey('filter-view-text'),
                selected: _textView,
                onPressed: () => setState(() => _textView = true)),
          ],
        ),
        const SizedBox(height: 8),
        if (!_textView) Expanded(child: _checksView(doc)),
        if (_textView)
          Expanded(
            child: TextField(
              key: const ValueKey('filter-text'),
              controller: _text,
              focusNode: _focus,
              maxLines: null,
              expands: true,
              keyboardType: TextInputType.multiline,
              textAlignVertical: TextAlignVertical.top,
              style: TextStyle(
                  fontFamily: RetroType.bodyFamily,
                  letterSpacing: RetroType.letterSpacing,
                  fontFamilyFallback: RetroType.bodyFallback,
                  fontSize: RetroType.small,
                  height: 1.8),
              decoration: const InputDecoration(
                  contentPadding: EdgeInsets.all(8), isDense: true),
            ),
          ),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.end,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            PanelButton('RESTAURAR POR DEFECTO',
                key: const ValueKey('filter-default'),
                onPressed: _text.text == LootFilterRules.defaultText
                    ? null
                    : () => _text.text = LootFilterRules.defaultText),
            PanelButton('DESHACER',
                key: const ValueKey('filter-revert'),
                onPressed: _text.text == _savedText
                    ? null
                    : () => _text.text = _savedText),
            PanelButton('GUARDAR',
                key: const ValueKey('filter-save'),
                accent: ProtoColors.green,
                reason: reason, onPressed: () {
              final t = _text.text;
              shop.controller
                  .setLootFilter(t == LootFilterRules.defaultText ? null : t);
              setState(() {});
            }),
          ],
        ),
      ],
    );

    // El plan del miembro activo: la vista previa evalúa `Build` igual
    // que el host.
    final wants = BuildWants.fromPlan(ref
        .watch(buildPlanProvider)
        .planFor(shop.controller.slotOf(shop.view.actorId)));
    final ctx = FilterContext(
        level: p.level,
        attributes: p.attributes,
        classId: p.classId,
        wants: wants);
    final f = parsed.filter;
    final side = PanelDetail(
      children: [
        const Text('VALIDACION', style: TextStyle(color: ProtoColors.gold)),
        ProtoText(
          key: const ValueKey('filter-status'),
          parsed.ok
              ? protoColor(ProtoColors.green,
                  'Sin errores · ${f.rules.length} regla${f.rules.length == 1 ? '' : 's'}')
              : protoColor(ProtoColors.red,
                  [for (final e in parsed.errors) protoEsc(e)].join('<br>')),
        ),
        if (p.lootFilter == null)
          Text(retroText('Usas el filtro por defecto.'),
              style: const TextStyle(color: ProtoColors.dim)),
        const SizedBox(height: 8),
        ..._buildSection(wants),
        const SizedBox(height: 8),
        const Text('VISTA PREVIA', style: TextStyle(color: ProtoColors.gold)),
        Text(retroText('Así se verían en el mapa (tu nivel ${p.level}):'),
            style: const TextStyle(color: ProtoColors.dim)),
        const SizedBox(height: 4),
        for (final (i, d) in filterSamples(p.level).indexed)
          _sample(rules, fr, f, d, ctx, i),
        const SizedBox(height: 8),
        const Text('GRAMATICA', style: TextStyle(color: ProtoColors.gold)),
        const ProtoText(kFilterGrammar,
            style: TextStyle(color: ProtoColors.dim)),
      ],
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(child: editor),
        const SizedBox(width: 16),
        SizedBox(width: 400, child: side),
      ],
    );
  }

  /// Vista CASILLAS: OCULTAR RÁPIDO (casillas que agregan / sacan reglas
  /// `# rápido: …`) y TUS REGLAS (cada regla con prender / apagar y ✕).
  /// Todo cambia el mismo texto (filter_quick.dart).
  Widget _checksView(FilterDoc doc) {
    final checked = doc.checked;
    Widget group(QuickGroup g) {
      final opts = [
        for (final o in _options)
          if (o.group == g) o
      ];
      return Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: RetroType.width(context, 150),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Text(retroText(g.label),
                    style: const TextStyle(color: ProtoColors.sky)),
              ),
            ),
            Expanded(
              child: Wrap(spacing: 14, children: [
                for (final o in opts)
                  FilterCheck(
                    key: ValueKey('filter-quick-${o.id}'),
                    label: o.label,
                    value: checked.contains(o.id),
                    color: g == QuickGroup.excepcion ? kPlanColor : null,
                    onChanged: (on) => _setText((doc.setQuick(o.id, on), 0)),
                  ),
              ]),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      key: const ValueKey('filter-checks'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(retroText('OCULTAR RÁPIDO'),
              style: const TextStyle(color: ProtoColors.gold)),
          Text(
              retroText(
                  'Marcá lo que no querés ver en el mapa. Por tipo, peso, '
                  'uso y nivel nunca se ocultan Épicas ni Legendarias. La '
                  'excepción ★ va primero y le gana a todo lo demás.'),
              style: const TextStyle(color: ProtoColors.dim)),
          const SizedBox(height: 6),
          for (final g in QuickGroup.values) group(g),
          const SizedBox(height: 8),
          Text(retroText('TUS REGLAS (${doc.blocks.length})'),
              key: const ValueKey('filter-rules-title'),
              style: const TextStyle(color: ProtoColors.gold)),
          Text(
              retroText(
                  'En orden, de arriba a abajo. La casilla apaga la regla '
                  'sin borrarla (queda en el texto con #OFF); ✕ la borra.'),
              style: const TextStyle(color: ProtoColors.dim)),
          const SizedBox(height: 4),
          if (doc.blocks.isEmpty)
            Text(retroText('Sin reglas: todo se ve con el color de su rareza.'),
                style: const TextStyle(color: ProtoColors.dim)),
          for (final (i, b) in doc.blocks.indexed) _ruleRow(doc, i, b),
        ],
      ),
    );
  }

  Widget _ruleRow(FilterDoc doc, int i, FilterBlock b) {
    final on = b.enabled;
    final verbColor = !on
        ? ProtoColors.dim
        : b.show
            ? ProtoColors.green
            : ProtoColors.red;
    final name = FilterDoc.summary(b);
    final conds = FilterDoc.conditionsText(b);
    return Padding(
      key: ValueKey('filter-rule-$i'),
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: Row(
        children: [
          FilterCheck(
            key: ValueKey('filter-rule-on-$i'),
            value: on,
            onChanged: (v) => _setText((doc.setEnabled(i, v), 0)),
          ),
          Expanded(
            child: RetroTooltip(
              message: protoEsc(b.text.trimRight()).replaceAll('\n', '<br>'),
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(
                      text: retroText(b.show ? 'Mostrar' : 'Ocultar'),
                      style: TextStyle(color: verbColor)),
                  TextSpan(
                      text: retroText(' · $name'),
                      style: TextStyle(
                          color: on ? ProtoColors.ink : ProtoColors.dim)),
                  if (name != conds)
                    TextSpan(
                        text: retroText(' · $conds'),
                        style: const TextStyle(color: ProtoColors.dim)),
                  if (b.errors.isNotEmpty)
                    TextSpan(
                        text: retroText(' · con errores'),
                        style: const TextStyle(color: ProtoColors.red)),
                ]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
            key: ValueKey('filter-rule-del-$i'),
            onTap: () => _setText((doc.remove(i), 0)),
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: Text('✕', style: TextStyle(color: ProtoColors.red)),
            ),
          ),
        ],
      ),
    );
  }

  /// Sección "Coincide con mi build" (condición `Build`, loot.md § 13):
  /// elegir qué parte del plan y agregarla a la regla del cursor o como
  /// una regla nueva que resalta / oculta.
  List<Widget> _buildSection(BuildWants wants) {
    String count(int n, String one, String many) => '$n ${n == 1 ? one : many}';
    final summary = wants.isEmpty
        ? 'No tenés plan de build: la condición no coincide con nada hasta '
            'que armes uno en la pestaña BUILD.'
        : 'Tu plan busca: ${[
            if (wants.weaponTypes.length + wants.weaponBases.length > 0)
              count(wants.weaponTypes.length + wants.weaponBases.length,
                  'base o tipo', 'bases o tipos'),
            if (wants.mods.isNotEmpty) count(wants.mods.length, 'mod', 'mods'),
            if (wants.weaponPassive != null) 'una pasiva',
            if (wants.skills.isNotEmpty)
              count(wants.skills.length, 'habilidad', 'habilidades'),
          ].join(' · ')}.';
    Widget kind(String label, BuildMatch? k) {
      final on = k == null ? _buildKinds.isEmpty : _buildKinds.contains(k);
      return PanelButton(label,
          key: ValueKey('filter-build-kind-${k?.name ?? 'any'}'),
          selected: on,
          accent: kPlanColor,
          onPressed: () => setState(() {
                if (k == null) {
                  _buildKinds.clear();
                } else if (!_buildKinds.remove(k)) {
                  _buildKinds.add(k);
                }
              }));
    }

    final cond = FilterBuildSnippets.condition(_buildKinds).text;
    return [
      Text(retroText('★ COINCIDE CON MI BUILD'),
          key: const ValueKey('filter-build-title'),
          style: const TextStyle(color: kPlanColor)),
      Text(
          retroText('Condición para tus reglas: el arma cumple algo de tu '
              'plan de build. En el mapa lleva ★. Elegí qué tiene que cumplir:'),
          style: const TextStyle(color: ProtoColors.dim)),
      const SizedBox(height: 4),
      Wrap(spacing: 6, runSpacing: 6, children: [
        kind('CUALQUIER META', null),
        kind('BASE O TIPO', BuildMatch.base),
        kind('MOD', BuildMatch.mod),
        kind('PASIVA', BuildMatch.pasiva),
        kind('HABILIDAD', BuildMatch.habilidad),
      ]),
      const SizedBox(height: 4),
      Text(retroText('Línea: $cond'),
          key: const ValueKey('filter-build-line'),
          style: const TextStyle(color: ProtoColors.ink)),
      const SizedBox(height: 4),
      Wrap(spacing: 6, runSpacing: 6, children: [
        PanelButton('+ A LA REGLA DEL CURSOR',
            key: const ValueKey('filter-build-insert'),
            onPressed: () => _setText(FilterBuildSnippets.insertCondition(
                _text.text, _text.selection.baseOffset, _buildKinds))),
        PanelButton('+ REGLA: RESALTAR',
            key: const ValueKey('filter-build-highlight'),
            accent: kPlanColor,
            onPressed: () => _setText(FilterBuildSnippets.prependRule(
                _text.text, FilterBuildSnippets.highlightRule(_buildKinds)))),
        PanelButton('+ REGLA: OCULTAR COMUNES FUERA DEL PLAN',
            key: const ValueKey('filter-build-hide'),
            onPressed: () => _setText(FilterBuildSnippets.prependRule(
                _text.text, FilterBuildSnippets.hideRule))),
      ]),
      const SizedBox(height: 4),
      Text(retroText(summary),
          key: const ValueKey('filter-build-plan'),
          style: const TextStyle(color: ProtoColors.dim)),
    ];
  }

  Widget _sample(ProgressionRules rules, LootFilterRules fr, LootFilter f,
      LootDrop d, FilterContext ctx, int i) {
    final v = fr.evaluate(f, d, ctx);
    final rule = v.ruleIndex == null
        ? 'sin regla: color de la rareza'
        : f.rules[v.ruleIndex!].name ?? 'regla ${v.ruleIndex! + 1}';
    final st = v.style;
    final extra = [
      if (v.buildMatch)
        '★ tu build: ${[for (final k in v.build) k.label].join(', ')}',
      if (v.visible && st.sound != null) 'sonido ${st.sound}',
      if (v.visible && st.icon != null)
        'ícono ${st.icon!.shape.name} ${st.icon!.color.name}',
    ];
    final it = d.item;
    return Padding(
      key: ValueKey('filter-sample-$i'),
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LootLabel(
            text: dropLabelText(rules, d),
            verdict: v,
            tooltip: it == null
                ? stackTooltipMarkup(d.stack!, d.count)
                : itemTooltipMarkup(rules, it,
                    level: ctx.level, attributes: ctx.attributes),
          ),
          Text(
              retroText(
                  '${it == null ? 'Material' : '${it.rarity.label} · nv ${it.itemLevel}'}'
                  ' · $rule${extra.isEmpty ? '' : ' · ${extra.join(' · ')}'}'),
              style: const TextStyle(color: ProtoColors.dim)),
        ],
      ),
    );
  }
}

/// Casilla `[x] texto` / `[ ] texto` (marcada en dorado, o en [color]).
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
    final on = color ?? ProtoColors.gold;
    return InkWell(
      onTap: () => onChanged(!value),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 2),
        child: Text.rich(TextSpan(children: [
          TextSpan(
              text: value ? '[x]' : '[ ]',
              style: TextStyle(color: value ? on : ProtoColors.dim)),
          if (label != null)
            TextSpan(
                text: retroText(' $label'),
                style: TextStyle(color: value ? on : ProtoColors.ink)),
        ])),
      ),
    );
  }
}

/// Para mostrar `FilterStyle` sin regla.
FilterVerdict defaultVerdict(LootDrop d) =>
    FilterVerdict(true, LootFilterRules.defaultStyle(d));
