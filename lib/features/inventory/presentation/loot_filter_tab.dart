import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../../app/theme/panel_frame.dart';
import '../../../app/theme/panel_widgets.dart';
import '../../../app/theme/proto_colors.dart';
import '../../../app/theme/proto_markup.dart';
import '../../../app/theme/retro_text.dart';
import '../../../app/theme/retro_theme.dart';
import '../../../game_engine/models/item.dart';
import '../../../game_engine/models/loot.dart';
import '../../../game_engine/models/loot_filter.dart';
import '../../../game_engine/models/player_profile.dart';
import '../../../game_engine/rules/loot_filter_rules.dart';
import '../../../game_engine/rules/progression_rules.dart';
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
    'Objeto Arma/Material/Pocion · Utilizable [Si/No].<br>'
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

/// Pestaña FILTRO del personaje: editor de texto del filtro de loot con
/// validación por línea, vista previa sobre objetos de muestra, guardar y
/// restaurar. El editor visual queda para la próxima versión. Ver
/// docs/specs/panels.md § "Filtro de loot".
class LootFilterTab extends StatefulWidget {
  const LootFilterTab({super.key, required this.shop});

  final ShopContext shop;

  @override
  State<LootFilterTab> createState() => _LootFilterTabState();
}

class _LootFilterTabState extends State<LootFilterTab> {
  late final _text = TextEditingController(text: _savedText);
  final _focus = FocusNode(debugLabel: 'loot-filter');

  PlayerProfile get _p => widget.shop.profile;
  String get _savedText => _p.lootFilter ?? LootFilterRules.defaultText;

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

    final editor = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: TextField(
            key: const ValueKey('filter-text'),
            controller: _text,
            focusNode: _focus,
            maxLines: null,
            expands: true,
            keyboardType: TextInputType.multiline,
            textAlignVertical: TextAlignVertical.top,
            style: TextStyle(fontFamily: RetroType.bodyFamily,
 fontFamilyFallback: RetroType.bodyFallback, fontSize: RetroType.small, height: 1.8),
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
                reason: reason,
                onPressed: () {
                  final t = _text.text;
                  shop.controller.setLootFilter(
                      t == LootFilterRules.defaultText ? null : t);
                  setState(() {});
                }),
          ],
        ),
      ],
    );

    final ctx = FilterContext(
        level: p.level, attributes: p.attributes, classId: p.classId);
    final f = parsed.filter;
    final side = PanelDetail(
      children: [
        const Text('VALIDACION', style: TextStyle(color: ProtoColors.gold)),
        ProtoText(
          key: const ValueKey('filter-status'),
          parsed.ok
              ? protoColor(ProtoColors.green,
                  'Sin errores · ${f.rules.length} regla${f.rules.length == 1 ? '' : 's'}')
              : protoColor(
                  ProtoColors.red,
                  [for (final e in parsed.errors) protoEsc(e)].join('<br>')),
        ),
        if (p.lootFilter == null)
          Text(retroText('Usas el filtro por defecto.'),
              style: const TextStyle(color: ProtoColors.dim)),
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

  Widget _sample(ProgressionRules rules, LootFilterRules fr, LootFilter f,
      LootDrop d, FilterContext ctx, int i) {
    final v = fr.evaluate(f, d, ctx);
    final rule = v.ruleIndex == null
        ? 'sin regla: color de la rareza'
        : f.rules[v.ruleIndex!].name ?? 'regla ${v.ruleIndex! + 1}';
    final st = v.style;
    final extra = [
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
              retroText('${it == null ? 'Material' : '${it.rarity.label} · nv ${it.itemLevel}'}'
                  ' · $rule${extra.isEmpty ? '' : ' · ${extra.join(' · ')}'}'),
              style: const TextStyle(color: ProtoColors.dim)),
        ],
      ),
    );
  }
}

/// Para mostrar `FilterStyle` sin regla.
FilterVerdict defaultVerdict(LootDrop d) =>
    FilterVerdict(true, LootFilterRules.defaultStyle(d));
