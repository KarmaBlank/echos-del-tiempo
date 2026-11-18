import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/panel_frame.dart';
import '../../../app/theme/panel_widgets.dart';
import '../../../app/theme/proto_colors.dart';
import '../../../app/theme/proto_markup.dart';
import '../../../app/theme/retro_text.dart';
import '../../../app/widgets/menu_widgets.dart';
import '../../../game_engine/models/item.dart';
import '../../../game_engine/models/player_profile.dart';
import '../../../game_engine/models/session_action.dart';
import '../../../game_engine/models/weapon.dart';
import '../../../game_engine/rules/craft_rules.dart';
import '../domain/item_text.dart';
import 'shop_sections.dart';

/// Grupos de la mesa (paso 2), en orden.
enum BenchGroup {
  improve('MEJORAR', 'cambia los mods de esta arma (con materiales)'),
  transfer('TRASLADAR', 'trae algo de otra arma (esa arma se destruye)'),
  remove('QUITAR', 'saca un mod para hacer lugar'),
  change('CAMBIAR', 'cambia la base del arma');

  const BenchGroup(this.label, this.note);
  final String label;
  final String note;
}

/// Textos de cada operación de la mesa en palabras simples (sin "slot"
/// ni "tier" sin explicar). Ver docs/specs/panels.md § "FUSIÓN".
extension CraftOpText on CraftOp {
  /// Operaciones de la mesa de fusión, en el orden del paso 2.
  static const bench = [
    CraftOp.reroll,
    CraftOp.addAffix,
    CraftOp.upgradeRarity,
    CraftOp.transferAffix,
    CraftOp.transferPassive,
    CraftOp.transferSkill,
    CraftOp.removeAffix,
    CraftOp.reforge,
  ];

  BenchGroup get group => switch (this) {
        CraftOp.reroll || CraftOp.addAffix || CraftOp.upgradeRarity =>
          BenchGroup.improve,
        CraftOp.transferAffix ||
        CraftOp.transferPassive ||
        CraftOp.transferSkill =>
          BenchGroup.transfer,
        CraftOp.removeAffix => BenchGroup.remove,
        _ => BenchGroup.change,
      };

  String get title => switch (this) {
        CraftOp.reroll => 'Re-tirar valores',
        CraftOp.addAffix => 'Agregar un mod',
        CraftOp.upgradeRarity => 'Subir rareza',
        CraftOp.transferAffix => 'Traer un mod',
        CraftOp.transferPassive => 'Traer la pasiva',
        CraftOp.transferSkill => 'Traer una habilidad',
        CraftOp.removeAffix => 'Quitar un mod',
        CraftOp.reforge => 'Reforjar base',
        CraftOp.salvage => 'Desarmar',
        CraftOp.sell => 'Vender',
        CraftOp.salvageAll => 'Desarmar todas',
        CraftOp.sellAll => 'Vender todas',
      };

  /// Explicación de 3-6 palabras para la fila del paso 2.
  String get short => switch (this) {
        CraftOp.reroll => 'Nuevos valores para cada mod',
        CraftOp.addAffix => 'Suma un mod al azar',
        CraftOp.upgradeRarity => 'Más lugar para mods',
        CraftOp.transferAffix => 'Copia un mod de otra arma',
        CraftOp.transferPassive => 'Trae la pasiva de otra Épica',
        CraftOp.transferSkill => 'Aprende una habilidad de otra arma',
        CraftOp.removeAffix => 'Borra un mod (no los fijos)',
        CraftOp.reforge => 'Otro tipo de arma, mismos mods',
        _ => line,
      };

  /// Una línea "qué hace".
  String get line => switch (this) {
        CraftOp.reroll =>
          'Nuevos valores para cada mod, dentro de su rango. Usa 1 Esquirla '
              'del Eco.',
        CraftOp.addAffix =>
          'Un mod al azar, si el arma tiene lugar. Usa 1 Cristal de Era.',
        CraftOp.upgradeRarity =>
          'Común → Mágico → Raro → Épico: más lugar para mods (y pasiva en '
              'Épico). Usa Prismas Rotos.',
        CraftOp.transferAffix =>
          'Copia un mod de otra arma a esta. La otra arma se destruye.',
        CraftOp.transferPassive =>
          'La pasiva de otra arma pasa a esta (las dos Épicas). La otra se '
              'destruye.',
        CraftOp.transferSkill =>
          'Esta arma aprende una habilidad de otra, que se destruye.',
        CraftOp.removeAffix =>
          'Borra un mod. Los mods fijos de un legendario no se quitan.',
        CraftOp.reforge =>
          'Cambia el tipo de arma (p. ej. arco → báculo) y conserva rareza, '
              'mods y forja.',
        CraftOp.salvage =>
          'Destruye el arma y te da materiales de fusión.',
        CraftOp.sell => 'Destruye el arma y te da créditos.',
        CraftOp.salvageAll => 'Desarma todas las armas de una rareza.',
        CraftOp.sellAll => 'Vende todas las armas de una rareza.',
      };

  /// Texto del botón de confirmar.
  String get verb => switch (this) {
        CraftOp.reroll => 'RE-TIRAR',
        CraftOp.addAffix => 'AGREGAR MOD',
        CraftOp.upgradeRarity => 'SUBIR RAREZA',
        CraftOp.transferAffix => 'TRAER MOD',
        CraftOp.transferPassive => 'TRAER PASIVA',
        CraftOp.transferSkill => 'TRAER HABILIDAD',
        CraftOp.removeAffix => 'QUITAR MOD',
        CraftOp.reforge => 'REFORJAR',
        CraftOp.salvage || CraftOp.salvageAll => 'DESARMAR',
        CraftOp.sell || CraftOp.sellAll => 'VENDER',
      };

  bool get needsSource =>
      this == CraftOp.transferAffix ||
      this == CraftOp.transferPassive ||
      this == CraftOp.transferSkill;

  bool get isRandom =>
      this == CraftOp.addAffix ||
      this == CraftOp.reroll ||
      this == CraftOp.upgradeRarity;
}

/// Ayuda de los tiers (tooltip junto a los mods).
const kTierHelp = '<b>Tiers de los mods</b><br>'
    'Cada mod tiene un tier: <b>T1</b> es el mejor (valores más altos) y '
    '<b>T5</b> el más bajo. Los tiers altos solo salen en armas de nivel '
    'alto (T4 desde nivel 10 … T1 desde nivel 40).<br>'
    '<span class="k">(único)</span> = mod fijo de un legendario.<br>'
    'Cada rareza tiene lugar para N mods: la mitad ofensivos (prefijos) y '
    'la mitad de atributos o defensa (sufijos).';

/// Ayuda de los materiales (tooltip del contador).
String materialsHelp() => [
      '<b>Materiales de fusión</b>',
      for (final m in CraftMaterial.values)
        '<span class="k">${m.label}</span>: ${protoEsc(m.description)}',
      'Caen como loot o salen de <b>desarmar</b> armas (Inventario).',
    ].join('<br>');

/// Costo de una operación para la columna derecha del paso 2:
/// `₵300 + 1 Cristal` (`Gratis` si no gasta nada).
String craftCostShort(CraftResult r) {
  final parts = [
    if (r.credits > 0) '₵${r.credits}',
    for (final e in r.materials.entries)
      '${e.value} ${e.key.label.split(' ').first}',
  ];
  return parts.isEmpty ? 'Gratis' : parts.join(' + ');
}

/// Mesa de fusión (pestaña FUSIÓN), en 3 pasos: **1 ARMA** (cuál) →
/// **2 ACCIÓN** (qué hacerle: una línea cada una con el costo o el motivo
/// a la derecha; el detalle explica la que tiene el mouse o el foco) →
/// **3 CONFIRMAR** (solo las elecciones de esa acción a la izquierda —
/// el arma origen y, debajo de ella, sus mods / habilidades — y a la
/// derecha ahora → después, lo que gastás y lo que perdés, con el botón
/// y su motivo). `Enter` confirma, `Esc` vuelve un paso. Ver
/// docs/specs/panels.md § "FUSIÓN".
class CraftBench extends StatefulWidget {
  const CraftBench({super.key, required this.shop, this.initialOp});

  final ShopContext shop;

  /// Arranca en el paso 3 con esta operación (y la equipada).
  final CraftOp? initialOp;

  @override
  State<CraftBench> createState() => _CraftBenchState();
}

class _CraftBenchState extends State<CraftBench> {
  late int _step = widget.initialOp == null ? 0 : 2;
  late CraftOp _op = widget.initialOp ?? CraftOp.reroll;
  String? _target, _source, _base;
  int _pick = 0;


  /// Familia del filtro de bases al reforjar (`null` = todas).
  late String? _family = widget.shop.profile.classId;

  /// La destino antes de la última operación (para mostrar qué salió).
  ItemInstance? _lastBefore;
  bool _done = false;

  final _focus = FocusNode(debugLabel: 'craft-bench');

  /// Lo que hace `Enter` en el paso actual (con el foco en la mesa).
  VoidCallback? _enter;

  ShopContext get shop => widget.shop;

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _go(int step) => setState(() {
        _step = step;
        _lastBefore = null;
        _done = false;
        _focus.requestFocus();
      });

  KeyEventResult _onKey(FocusNode node, KeyEvent e) {
    if (e is! KeyDownEvent) return KeyEventResult.ignored;
    if (e.logicalKey == LogicalKeyboardKey.escape && _step > 0) {
      _go(_step - 1);
      return KeyEventResult.handled;
    }
    if ((e.logicalKey == LogicalKeyboardKey.enter ||
            e.logicalKey == LogicalKeyboardKey.numpadEnter) &&
        FocusManager.instance.primaryFocus == _focus &&
        _enter != null) {
      _enter!();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  // ------------------------------------------------------------------
  // Elección por defecto y acción
  // ------------------------------------------------------------------

  /// Armas que sirven de origen para [op] hacia [target].
  List<ItemInstance> _sources(
      PlayerProfile p, ItemInstance target, CraftOp op) {
    final all = shop.guards.sacrifices(p, target.uid);
    return switch (op) {
      CraftOp.transferAffix => [
          for (final i in all)
            if (i.affixes.any((a) => !a.fixed)) i
        ],
      CraftOp.transferPassive => [
          for (final i in all)
            if (i.rarity.hasPassive && i.passiveId != null) i
        ],
      _ => all,
    };
  }

  List<WeaponDef> _bases(ItemInstance target) => [
        for (final w in shop.rules.crafting.reforgeBases(target))
          if (_family == null || w.classId == _family) w,
      ];

  /// La acción del paso 3 con lo elegido (o lo primero válido).
  CraftAction _action(PlayerProfile p, ItemInstance target, CraftOp op,
      {bool remember = false}) {
    String? source, base, skill;
    var pick = _pick;
    if (op.needsSource) {
      final list = _sources(p, target, op);
      source = (list.where((i) => i.uid == _source).firstOrNull ??
              list.firstOrNull)
          ?.uid;
    }
    if (op == CraftOp.reforge) {
      final list = _bases(target);
      base = (list.where((w) => w.id == _base).firstOrNull ?? list.firstOrNull)
          ?.id;
    }
    final n = _picks(p, target, op, source).length;
    if (pick >= n) pick = 0;
    if (op == CraftOp.transferSkill && source != null) {
      skill =
          shop.rules.items.skillsOf(p.itemByUid(source)!).elementAtOrNull(pick);
    }
    if (remember) {
      _source = source;
      _base = base;
      _pick = pick;
    }
    if (op == CraftOp.reforge) {
      return CraftAction(op, target.uid, sourceUid: base);
    }
    return CraftAction(op, target.uid,
        sourceUid: source, index: pick, skillId: skill);
  }

  /// Elementos elegibles (mods o habilidades) en markup.
  List<String> _picks(
      PlayerProfile p, ItemInstance target, CraftOp op, String? sourceUid) {
    final rules = shop.rules;
    final source = sourceUid == null ? null : p.itemByUid(sourceUid);
    return switch (op) {
      CraftOp.transferAffix => [
          for (final a in source?.affixes ?? const <AffixRoll>[])
            affixMarkup(rules, a),
        ],
      CraftOp.transferSkill => [
          for (final id in source == null
              ? const <String>[]
              : rules.items.skillsOf(source))
            protoEsc(skillName(rules, id)),
        ],
      CraftOp.removeAffix => [
          for (final a in target.affixes) affixMarkup(rules, a),
        ],
      _ => const [],
    };
  }

  /// Motivo corto para el paso 2 (con la elección por defecto).
  String? _quickReason(PlayerProfile p, ItemInstance target, CraftOp op) {
    if (op.needsSource && _sources(p, target, op).isEmpty) {
      return switch (op) {
        CraftOp.transferAffix => 'No tienes otra arma con mods',
        CraftOp.transferPassive => 'No tienes otra arma con pasiva',
        _ => 'No tienes otra arma',
      };
    }
    if (op == CraftOp.reforge &&
        target.rarity != Rarity.legendario &&
        shop.rules.crafting.reforgeBases(target).isEmpty) {
      return 'No hay bases de su nivel';
    }
    if (op == CraftOp.transferAffix || op == CraftOp.transferPassive) {
      // "Se puede" si alguna combinación (arma × mod) es válida; si no, el
      // motivo de la primera.
      String? first;
      for (final s in _sources(p, target, op)) {
        final n = op == CraftOp.transferAffix ? s.affixes.length : 1;
        for (var i = 0; i < n; i++) {
          final why = shop.guards.craft(
              p, CraftAction(op, target.uid, sourceUid: s.uid, index: i));
          if (why == null) return null;
          first ??= why;
        }
      }
      return first;
    }
    final a = _action(p, target, op);
    if (op == CraftOp.reforge && a.sourceUid == null) {
      // El filtro de familia puede dejar la lista vacía: probamos todas.
      final any = shop.rules.crafting.reforgeBases(target).firstOrNull;
      return any == null
          ? 'No hay bases de su nivel'
          : shop.guards.craft(p, CraftAction.reforge(target.uid, any.id));
    }
    return shop.guards.craft(p, a);
  }

  // ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final p = shop.profile;
    final items = shop.owned;
    if (items.isEmpty) return const Text('No tienes armas.');
    final target =
        items.firstWhere((i) => i.uid == _target, orElse: () => items.first);
    _target = target.uid;
    _enter = null;
    final body = switch (_step) {
      0 => _weaponStep(p, items, target),
      1 => _opStep(p, target),
      _ => _confirmStep(p, target),
    };
    return Focus(
      focusNode: _focus,
      onKeyEvent: _onKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(p, target),
          const SizedBox(height: 6),
          Expanded(
              child: KeyedSubtree(
                  key: ValueKey('bench-step-$_step'), child: body)),
        ],
      ),
    );
  }

  /// Migas (pasos, se puede volver) y contador de materiales.
  Widget _header(PlayerProfile p, ItemInstance target) {
    final mats = [
      for (final m in CraftMaterial.values)
        '${m.label.split(' ').first} <b>x${p.material(m)}</b>',
    ].join(' · ');
    return Row(
      children: [
        StepCrumbs(
          steps: const ['ARMA', 'ACCIÓN', 'CONFIRMAR'],
          current: _step,
          keyPrefix: 'bench-crumb-',
          onStep: _go,
        ),
        const SizedBox(width: 12),
        // Lo elegido en los pasos anteriores, al lado de las migas.
        if (_step > 0)
          Expanded(
            child: ProtoText(
                key: const ValueKey('bench-summary'),
                '${itemNameMarkup(shop.rules, target)}'
                '${_step == 2 ? ' · <span class="k">${protoEsc(_op.title)}</span>' : ''}'),
          ),
        if (_step == 0) const Spacer(),
        const SizedBox(width: 12),
        Flexible(
          flex: 0,
          child: Align(
            alignment: Alignment.centerRight,
            child: RetroTooltip(
              message: materialsHelp(),
              child: ProtoText(mats,
                  key: const ValueKey('craft-materials'),
                  textAlign: TextAlign.right),
            ),
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------------
  // Paso 1: ¿qué arma?
  // ------------------------------------------------------------------

  Widget _weaponStep(
      PlayerProfile p, List<ItemInstance> items, ItemInstance target) {
    final rules = shop.rules;
    _enter = () => _go(1);
    return PanelSplit(
      listWidth: 480,
      list: [
        for (final it in items)
          MenuRow(
            wrap: true,
            key: ValueKey('bench-weapon-${it.uid}'),
            selected: it.uid == target.uid,
            onTap: () {
              if (it.uid == target.uid) return _go(1);
              setState(() {
                _target = it.uid;
                _pick = 0;
                _source = null;
              });
              _focus.requestFocus();
            },
            label: itemNameMarkup(rules, it),
            value: it.uid == p.equippedUid
                ? protoColor(ProtoColors.gold, 'EQUIPADA')
                : protoColor(ProtoColors.dim,
                    '${it.rarity.label} · Nv ${rules.items.baseOf(it)?.level ?? 1}'),
          ),
      ],
      detail: PanelDetail(
        footer: [
          const KeyHints(back: null),
          PanelButton('ELEGIR ›',
              key: const ValueKey('bench-next'),
              accent: ProtoColors.green,
              onPressed: () => _go(1)),
        ],
        children: [
          ItemCard(
              rules: rules,
              item: target,
              level: p.level,
              attributes: p.attributes,
              equipped: target.uid == p.equippedUid),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------
  // Paso 2: ¿qué hacer?
  // ------------------------------------------------------------------

  Widget _opStep(PlayerProfile p, ItemInstance target) {
    void choose(CraftOp op) => setState(() {
          _op = op;
          _pick = 0;
          _source = null;
          _base = null;
          _step = 2;
            _lastBefore = null;
          _done = false;
          _focus.requestFocus();
        });
    _enter = () => choose(_op);
    // Todo el ancho para la lista (sin ficha grande al costado): cada grupo
    // con su título y qué hace; cada acción con su explicación y, a la
    // derecha, el costo o el motivo completo. Nada se corta.
    final rows = <Widget>[];
    for (final g in BenchGroup.values) {
      rows.add(Padding(
        padding: EdgeInsets.only(top: g.index == 0 ? 0 : 4, bottom: 2),
        child: Row(
          children: [
            Expanded(
              child: ProtoText('<b>${g.label}</b> '
                  '${protoColor(ProtoColors.sky, '— ${protoEsc(g.note)}')}'),
            ),
            if (g.index == 0) const KeyHints(),
          ],
        ),
      ));
      for (final op in CraftOpText.bench) {
        if (op.group != g) continue;
        final why = _quickReason(p, target, op);
        // Costo con la elección por defecto; si esa no vale (p. ej. el mod
        // depende del origen), solo "Se puede".
        final pre = shop.guards.craftPreview(p, _action(p, target, op));
        final cost = pre.error == null ? craftCostShort(pre) : 'Se puede';
        rows.add(MenuRow(
          wrap: true,
          key: ValueKey('bench-op-${op.name}'),
          selected: op == _op,
          onTap: () => choose(op),
          label: '<b>${protoEsc(op.title)}</b>',
          description: protoEsc(op.short),
          valueKey: ValueKey('bench-op-why-${op.name}'),
          value: why == null
              ? protoColor(ProtoColors.green, protoEsc(cost))
              : protoColor(ProtoColors.red, protoEsc(why)),
        ));
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: rows,
            ),
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------------
  // Paso 3: vista previa y confirmar
  // ------------------------------------------------------------------

  Widget _confirmStep(PlayerProfile p, ItemInstance target) {
    final rules = shop.rules;
    final op = _op;
    final action = _action(p, target, op, remember: true);
    final r = shop.guards.craftPreview(p, action);
    final reason = shop.guards.craft(p, action);

    void confirm() {
      final before = target;
      if (shop.controller.craft(action)) {
        setState(() {
          _lastBefore = before;
          _done = true;
          if (op.needsSource) _source = null;
          _pick = 0;
        });
      }
    }

    if (reason == null) _enter = confirm;

    Widget row(String key, String label, bool sel, VoidCallback onTap,
            {String? value, double indent = 0}) =>
        MenuRow(
          wrap: true,
          key: ValueKey(key),
          selected: sel,
          indent: indent,
          onTap: () {
            setState(() {
              onTap();
              _lastBefore = null;
              _done = false;
            });
            _focus.requestFocus();
          },
          label: label,
          value: value,
        );
    Widget dim(String t) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(retroText(t),
              style: const TextStyle(color: ProtoColors.dim)),
        );

    final picks =
        _picks(p, target, op, op.needsSource ? action.sourceUid : null);
    List<Widget> pickRows({double indent = 0}) => [
          for (var i = 0; i < picks.length; i++)
            row('craft-pick-$i', picks[i], i == action.index,
                () => _pick = i, indent: indent),
        ];

    final list = <Widget>[dim(op.line)];
    if (op.needsSource) {
      final sources = _sources(p, target, op);
      list.add(const MenuHeader('¿De qué arma? (se destruye)'));
      if (sources.isEmpty) {
        list.add(dim(_quickReason(p, target, op) ??
            'No hay armas (no la equipada ni tu última arma inicial)'));
      }
      for (final it in sources) {
        final sel = it.uid == action.sourceUid;
        list.add(row(
            'craft-source-${it.uid}',
            itemNameMarkup(rules, it),
            sel,
            () {
              _source = it.uid;
              _pick = 0;
            },
            value: protoColor(ProtoColors.dim,
                '${it.rarity.label} · Nv ${rules.items.baseOf(it)?.level ?? 1}')));
        // Las elecciones de esa arma, justo debajo (sin bajar a buscarlas).
        if (sel && op != CraftOp.transferPassive) {
          if (picks.isEmpty) {
            list.add(Padding(
                padding: const EdgeInsets.only(left: 24),
                child: dim(op == CraftOp.transferSkill
                    ? '(sin habilidades)'
                    : '(no tiene mods)')));
          }
          list.addAll(pickRows(indent: 24));
        }
      }
    }
    if (op == CraftOp.removeAffix) {
      list.add(const MenuHeader('¿Qué mod quitar?'));
      if (picks.isEmpty) list.add(dim('(no tiene mods)'));
      list.addAll(pickRows());
    }
    if (op == CraftOp.reforge) {
      list.add(const MenuHeader('¿Qué base nueva?'));
      list.add(ChoiceCycler<String?>(
        label: 'Familia',
        keyPrefix: 'bench-family-',
        options: [null, ...rules.catalog.classes.keys],
        value: _family,
        display: (id) => id == null
            ? 'TODAS'
            : (rules.catalog.classes[id]?.name ?? id).toUpperCase(),
        onChanged: (id) => setState(() {
          _family = id;
          _lastBefore = null;
          _done = false;
        }),
      ));
      list.add(const SizedBox(height: 4));
      final bases = _bases(target);
      if (bases.isEmpty) list.add(dim('(ninguna de esta familia)'));
      for (final w in bases) {
        list.add(row(
            'bench-base-${w.id}',
            '${protoEsc(w.name)} ${protoColor(ProtoColors.dim, protoEsc(w.type))}',
            w.id == action.sourceUid,
            () => _base = w.id,
            value: 'Nv ${w.level} '
                '${rules.meetsRequirements(p, w) ? protoColor(ProtoColors.green, 'OK') : protoColor(ProtoColors.red, 'Req')}'));
      }
    }
    if (list.length == 1) {
      list.add(const SizedBox(height: 4));
      list.add(const Text('AHORA', style: TextStyle(color: ProtoColors.gold)));
      list.add(ItemCard(
          rules: rules,
          item: target,
          level: p.level,
          attributes: p.attributes,
          equipped: target.uid == p.equippedUid));
    }

    return PanelSplit(
      listWidth: 480,
      list: list,
      detail: PanelDetail(
        footer: [
          const KeyHints(),
          PanelButton('‹ OTRA ACCIÓN',
              key: const ValueKey('bench-back'), onPressed: () => _go(1)),
          PanelButton(op.verb,
              key: const ValueKey('craft-confirm'),
              accent: ProtoColors.green,
              reason: reason,
              onPressed: confirm),
        ],
        children: [
          ..._preview(p, target, op, r),
        ],
      ),
    );
  }

  List<Widget> _preview(
      PlayerProfile p, ItemInstance target, CraftOp op, CraftResult r) {
    final rules = shop.rules;
    final after = r.after;
    Widget title(String t) => Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 2),
          child: Text(retroText(t),
              style: const TextStyle(color: ProtoColors.gold)),
        );
    final out = <Widget>[];
    final last = _lastBefore;
    if (_done && last != null && last.uid == target.uid) {
      out.add(ProtoText(
          key: const ValueKey('craft-last'),
          last == target
              ? protoColor(ProtoColors.green, '¡Listo!')
              : '${protoColor(ProtoColors.green, '¡Listo! Ahora:')} '
                  '${_diffMods(last, target)}'));
    }

    // Lo que cuesta y lo que se pierde, primero: se ve sin bajar.
    out.add(InfoLine('Gastas', _spendMarkup(r, p),
        key: const ValueKey('craft-cost'), color: ProtoColors.gold));
    final lost = <String>[
      for (final uid in r.consumed)
        if (p.itemByUid(uid) case final it?)
          '${itemNameMarkup(rules, it)} (se destruye con sus mods, pasiva y forja)',
      if (r.replaced != null) 'Reemplaza ${protoEsc(r.replaced!)}',
      for (final l in r.lost) protoEsc(l),
    ];
    out.add(InfoLine(
        'Pierdes',
        key: const ValueKey('craft-lost'),
        color: ProtoColors.gold,
        lost.isEmpty
            ? protoColor(ProtoColors.green, 'Nada')
            : protoColor(ProtoColors.red, lost.join('<br>'))));
    if (r.error != null) {
      out.add(ProtoText(
          key: const ValueKey('craft-error'),
          protoColor(ProtoColors.red, 'No se puede: ${protoEsc(r.error!)}')));
    }

    // AHORA → DESPUÉS
    out.add(title(after == null && op.isRandom
        ? 'ANTES → DESPUÉS (al azar)'
        : 'ANTES → DESPUÉS'));
    final name = after == null ||
            rules.items.displayName(after) == rules.items.displayName(target)
        ? itemNameMarkup(rules, target)
        : '${itemNameMarkup(rules, target)} → ${itemNameMarkup(rules, after)}';
    out.add(ProtoText(name, key: const ValueKey('craft-name')));
    if (after != null && after.baseId != target.baseId) {
      final b0 = rules.items.baseOf(target), b1 = rules.items.baseOf(after);
      out.add(ProtoText(
          key: const ValueKey('craft-base'),
          'Base: ${protoEsc(b0?.name ?? target.baseId)} '
          '<small>(${protoEsc(b0?.type ?? '?')})</small> → '
          '<b>${protoEsc(b1?.name ?? after.baseId)}</b> '
          '<small>(${protoEsc(b1?.type ?? '?')}, Nv ${b1?.level ?? '?'})</small>'));
      if (b1 != null) {
        out.add(ProtoText(requirementsLineMarkup(b1, p.level, p.attributes)));
      }
    }
    if (after != null && after.rarity != target.rarity) {
      out.add(ProtoText('Rareza ${target.rarity.label} → '
          '<b style="color:${rarityHex(after.rarity)}">${after.rarity.label}</b>'));
    }
    final shown = after ?? target;
    out.add(Row(
      children: [
        Flexible(
          child: ProtoText(
              key: const ValueKey('craft-mods-title'),
              '<span class="k">Mods ${shown.modCount}/${shown.rarity.maxMods}</span> '
              '<small>(lugar de un ${shown.rarity.label})</small>'),
        ),
        const SizedBox(width: 6),
        const RetroTooltip(
          key: ValueKey('craft-tier-help'),
          message: kTierHelp,
          child: Text('[¿T1–T5?]', style: TextStyle(color: ProtoColors.sky)),
        ),
      ],
    ));
    out.add(ProtoText(
        key: const ValueKey('craft-mods'),
        after == null ? _modList(target) : _diffMods(target, after)));
    final pBefore = rules.items.passiveText(target);
    final pAfter = after == null ? pBefore : rules.items.passiveText(after);
    if (pBefore != null || pAfter != null) {
      out.add(ProtoText(
          key: const ValueKey('craft-passive'),
          pBefore == pAfter
              ? 'Pasiva: <span style="color:$kPassiveHex">${protoEsc(pBefore!)}</span>'
              : 'Pasiva: ${protoColor(ProtoColors.dim, protoEsc(pBefore ?? '—'))} → '
                  '<b style="color:$kPassiveHex">${protoEsc(pAfter ?? '—')}</b>'));
    }
    final sBefore = rules.items.skillsOf(target);
    final sAfter = after == null ? sBefore : rules.items.skillsOf(after);
    out.add(ProtoText(
        key: const ValueKey('craft-skills'),
        'Habilidades: ${[
          for (final id in sAfter)
            sBefore.contains(id)
                ? protoEsc(skillName(rules, id))
                : protoColor(ProtoColors.green,
                    '<b>${protoEsc(skillName(rules, id))}</b> (nueva)'),
        ].join(' · ')} '
        '<small>(traídas ${shown.extraSkills.length}/${shown.rarity.skillSlots})</small>'));
    if (r.outcomes.isNotEmpty) {
      out.add(title('PUEDE SALIR'));
      out.add(ProtoText(
          key: const ValueKey('craft-outcomes'),
          protoColor(ProtoColors.sky, protoEsc(r.outcomes.join(' · ')))));
    }
    if (after != null && rules.catalog.weapons.containsKey(after.baseId)) {
      out.add(StatsCompare(
        title: 'Tus stats si la equipas',
        before: shop.preview.withItem(p, target),
        after: shop.preview.withItem(p, after),
      ));
    }
    return out;
  }

  /// `₵N (tienes M) · 1 Cristal de Era (tienes K)`, en rojo lo que falta.
  String _spendMarkup(CraftResult r, PlayerProfile p) {
    String part(bool ok, String t) =>
        ok ? t : protoColor(ProtoColors.red, t);
    final parts = [
      if (r.credits > 0)
        part(p.credits >= r.credits,
            '<b>₵${r.credits}</b> (tienes ₵${p.credits})'),
      for (final e in r.materials.entries)
        part(p.material(e.key) >= e.value,
            '${e.value} ${e.key.label} (tienes ${p.material(e.key)})'),
    ];
    return parts.isEmpty
        ? protoColor(ProtoColors.green, 'Nada')
        : parts.join(' · ');
  }

  String _modList(ItemInstance it) {
    final rules = shop.rules;
    if (it.affixes.isEmpty) return protoColor(ProtoColors.dim, '(sin mods)');
    return [for (final a in it.affixes) '• ${affixMarkup(rules, a)}']
        .join('<br>');
  }

  /// Lista de mods después, con lo nuevo en verde y lo quitado en rojo.
  String _diffMods(ItemInstance before, ItemInstance after) {
    final rules = shop.rules;
    final lines = <String>[
      for (final a in before.affixes)
        if (!after.affixes.contains(a))
          '• ${protoColor(ProtoColors.red, '${protoEsc(rules.items.affixText(a))} (se quita)')}',
      for (final a in after.affixes)
        before.affixes.contains(a)
            ? '• ${affixMarkup(rules, a)}'
            : '• ${protoColor(ProtoColors.green, '<b>${protoEsc(rules.items.affixText(a))}</b> (nuevo)')}',
    ];
    return lines.isEmpty
        ? protoColor(ProtoColors.dim, '(sin mods)')
        : lines.join('<br>');
  }
}
