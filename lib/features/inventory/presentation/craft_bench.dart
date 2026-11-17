import 'package:material_ui/material_ui.dart';

import '../../../app/theme/panel_frame.dart';
import '../../../app/theme/panel_widgets.dart';
import '../../../app/theme/proto_colors.dart';
import '../../../app/theme/proto_markup.dart';
import '../../../app/theme/retro_text.dart';
import '../../../game_engine/models/item.dart';
import '../../../game_engine/models/player_profile.dart';
import '../../../game_engine/models/session_action.dart';
import '../../../game_engine/models/weapon.dart';
import '../../../game_engine/rules/craft_rules.dart';
import '../domain/item_text.dart';
import 'shop_sections.dart';

/// Grupos de la mesa (paso 2), en orden.
enum BenchGroup {
  improve('MEJORAR', 'con materiales'),
  transfer('TRASLADAR', 'de otra arma, que se destruye'),
  remove('QUITAR', 'para hacer lugar'),
  change('CAMBIAR', 'el tipo de arma');

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

/// Mesa de fusión (pestaña FUSIÓN), en 3 pasos: **1 ARMA** (cuál) →
/// **2 ACCIÓN** (qué hacerle, con una línea cada una y el motivo si no se
/// puede) → **3 CONFIRMAR** (lo que se elige a la izquierda y, a la
/// derecha, ahora → después, lo que gastás con lo que tenés, lo que perdés
/// y el botón con el motivo). Ver docs/specs/panels.md § "FUSIÓN".
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

  ShopContext get shop => widget.shop;

  void _go(int step) => setState(() {
        _step = step;
        _lastBefore = null;
        _done = false;
      });

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
      skill = shop.rules.items.skillsOf(p.itemByUid(source)!).elementAtOrNull(pick);
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
    final body = switch (_step) {
      0 => _weaponStep(p, items, target),
      1 => _opStep(p, target),
      _ => _confirmStep(p, target),
    };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(p, target),
        const SizedBox(height: 8),
        Expanded(child: KeyedSubtree(key: ValueKey('bench-step-$_step'), child: body)),
      ],
    );
  }

  /// Migas (pasos, se puede volver) y contador de materiales.
  Widget _header(PlayerProfile p, ItemInstance target) {
    final rules = shop.rules;
    final mats = [
      for (final m in CraftMaterial.values)
        '${m.label.split(' ').first} <b>x${p.material(m)}</b>',
    ].join(' · ');
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              PanelButton('1 ARMA',
                  key: const ValueKey('bench-crumb-0'),
                  selected: _step == 0,
                  accent: _step == 0 ? ProtoColors.gold : null,
                  onPressed: () => _go(0)),
              const Text('›', style: TextStyle(color: ProtoColors.dim)),
              PanelButton('2 ACCIÓN',
                  key: const ValueKey('bench-crumb-1'),
                  selected: _step == 1,
                  accent: _step == 1 ? ProtoColors.gold : null,
                  onPressed: () => _go(1)),
              const Text('›', style: TextStyle(color: ProtoColors.dim)),
              PanelButton('3 CONFIRMAR',
                  key: const ValueKey('bench-crumb-2'),
                  selected: _step == 2,
                  accent: _step == 2 ? ProtoColors.gold : null,
                  onPressed: () => _go(2)),
              const SizedBox(width: 6),
              ProtoText(
                  key: const ValueKey('bench-summary'),
                  _step == 0
                      ? protoColor(ProtoColors.dim, '¿Qué arma?')
                      : '${itemNameMarkup(rules, target)}'
                          '${_step == 2 ? ' · <span class="k">${protoEsc(_op.title)}</span>' : ''}'),
            ],
          ),
        ),
        const SizedBox(width: 12),
        RetroTooltip(
          message: materialsHelp(),
          child: ProtoText('Tienes: $mats', key: const ValueKey('craft-materials')),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PanelHint('Paso 1 de 3: elige el arma que quieres mejorar o '
            'cambiar.'),
        Expanded(
          child: PanelSplit(
            list: [
              for (final it in items)
                PanelListItem(
                  key: ValueKey('bench-weapon-${it.uid}'),
                  selected: it.uid == target.uid,
                  onTap: () => setState(() {
                    _target = it.uid;
                    _pick = 0;
                    _source = null;
                  }),
                  trailing: it.uid == p.equippedUid
                      ? const Text('EQUIPADA',
                          style: TextStyle(color: ProtoColors.gold))
                      : null,
                  child: ProtoText(itemRowMarkup(rules, it)),
                ),
            ],
            detail: PanelDetail(
              footer: [
                PanelButton('ELEGIR ESTA ARMA ›',
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
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------------
  // Paso 2: ¿qué hacer?
  // ------------------------------------------------------------------

  Widget _opStep(PlayerProfile p, ItemInstance target) {
    final rules = shop.rules;
    final rows = <Widget>[];
    BenchGroup? group;
    for (final op in CraftOpText.bench) {
      if (op.group != group) {
        group = op.group;
        rows.add(ProtoText(
            '<b style="color:#ffd166">${group.label}</b> '
            '${protoColor(ProtoColors.dim, group.note)}'));
        rows.add(const SizedBox(height: 4));
      }
      final why = _quickReason(p, target, op);
      rows.add(PanelListItem(
        key: ValueKey('bench-op-${op.name}'),
        selected: op == _op,
        onTap: () => setState(() {
          _op = op;
          _pick = 0;
          _source = null;
          _base = null;
          _step = 2;
          _lastBefore = null;
          _done = false;
        }),
        trailing: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 190),
          child: KeyedSubtree(
            key: ValueKey('bench-op-why-${op.name}'),
            child: Text(retroText(why ?? 'Se puede'),
                textAlign: TextAlign.right,
                style: TextStyle(
                    fontSize: 8,
                    color: why == null ? ProtoColors.green : ProtoColors.red)),
          ),
        ),
        child: ProtoText('<b>${protoEsc(op.title)}</b><br>'
            '<small>${protoEsc(op.line)}</small>'),
      ));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const PanelHint('Paso 2 de 3: ¿qué quieres hacer? Elige una acción '
            'para ver el resultado antes de pagar.'),
        Expanded(
          child: PanelSplit(
            listWidth: 560,
            list: rows,
            detail: PanelDetail(
              children: [
                const Text('AHORA', style: TextStyle(color: ProtoColors.gold)),
                const SizedBox(height: 4),
                ItemCard(
                    rules: rules,
                    item: target,
                    level: p.level,
                    attributes: p.attributes,
                    equipped: target.uid == p.equippedUid),
              ],
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

    Widget row(String key, String markup, bool sel, VoidCallback onTap,
            {Widget? trailing}) =>
        PanelListItem(
          key: ValueKey(key),
          selected: sel,
          onTap: () => setState(() {
            onTap();
            _lastBefore = null;
            _done = false;
          }),
          trailing: trailing,
          child: ProtoText(markup),
        );
    Widget dim(String t) =>
        Text(retroText(t), style: const TextStyle(color: ProtoColors.dim));

    final list = <Widget>[];
    if (op.needsSource) {
      final sources = _sources(p, target, op);
      list.add(const ListHeader('¿De qué arma? (se destruye)'));
      if (sources.isEmpty) {
        list.add(dim(_quickReason(p, target, op) ??
            'No hay armas (no la equipada ni tu última arma inicial)'));
      }
      for (final it in sources) {
        list.add(row('craft-source-${it.uid}', itemRowMarkup(rules, it),
            it.uid == action.sourceUid, () {
          _source = it.uid;
          _pick = 0;
        }));
      }
    }
    final picks = _picks(p, target, op, op.needsSource ? action.sourceUid : null);
    if (op == CraftOp.transferAffix || op == CraftOp.removeAffix) {
      list.add(ListHeader(
          op == CraftOp.transferAffix ? '¿Qué mod traer?' : '¿Qué mod quitar?'));
      if (picks.isEmpty && (op == CraftOp.removeAffix || action.sourceUid != null)) {
        list.add(dim('(no tiene mods)'));
      }
    }
    if (op == CraftOp.transferSkill && action.sourceUid != null) {
      list.add(const ListHeader('¿Qué habilidad?'));
    }
    for (var i = 0; i < picks.length; i++) {
      list.add(row('craft-pick-$i', picks[i], i == action.index, () => _pick = i));
    }
    if (op == CraftOp.reforge) {
      list.add(const ListHeader('¿Qué base nueva?'));
      list.add(Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          PanelButton('TODAS',
              key: const ValueKey('bench-family-all'),
              selected: _family == null,
              onPressed: () => setState(() => _family = null)),
          for (final c in rules.catalog.classes.values)
            PanelButton(c.name.toUpperCase(),
                key: ValueKey('bench-family-${c.id}'),
                selected: _family == c.id,
                onPressed: () => setState(() => _family = c.id)),
        ],
      ));
      list.add(const SizedBox(height: 6));
      final bases = _bases(target);
      if (bases.isEmpty) list.add(dim('(ninguna de esta familia: prueba TODAS)'));
      for (final w in bases) {
        list.add(row(
            'bench-base-${w.id}',
            '${protoEsc(w.name)}<br><small>Nv ${w.level} · ${protoEsc(w.type)}</small>',
            w.id == action.sourceUid,
            () => _base = w.id,
            trailing: ProtoText(rules.meetsRequirements(p, w)
                ? protoColor(ProtoColors.green, 'OK')
                : protoColor(ProtoColors.red, 'Req'))));
      }
    }
    if (list.isEmpty) {
      list.add(const Text('AHORA', style: TextStyle(color: ProtoColors.gold)));
      list.add(const SizedBox(height: 4));
      list.add(ItemCard(
          rules: rules,
          item: target,
          level: p.level,
          attributes: p.attributes,
          equipped: target.uid == p.equippedUid));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PanelHint('Paso 3 de 3 · ${protoEsc(op.title)}: ${protoEsc(op.line)}'),
        Expanded(
          child: PanelSplit(
            list: list,
            detail: PanelDetail(
              footer: [
                PanelButton('‹ OTRA ACCIÓN',
                    key: const ValueKey('bench-back'),
                    onPressed: () => _go(1)),
                PanelButton(op.verb,
                    key: const ValueKey('craft-confirm'),
                    accent: ProtoColors.green,
                    reason: reason,
                    onPressed: () {
                      final before = target;
                      if (shop.controller.craft(action)) {
                        setState(() {
                          _lastBefore = before;
                          _done = true;
                          if (op.needsSource) _source = null;
                          _pick = 0;
                        });
                      }
                    }),
              ],
              children: _preview(p, target, op, r),
            ),
          ),
        ),
      ],
    );
  }

  List<Widget> _preview(
      PlayerProfile p, ItemInstance target, CraftOp op, CraftResult r) {
    final rules = shop.rules;
    final after = r.after;
    Widget title(String t) => Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 2),
          child: Text(retroText(t), style: const TextStyle(color: ProtoColors.gold)),
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

    // AHORA → DESPUÉS
    out.add(title(after == null && op.isRandom
        ? 'AHORA → DESPUÉS (al azar)'
        : 'AHORA → DESPUÉS'));
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
    // GASTAS
    out.add(title('GASTAS'));
    out.add(ProtoText(_spendMarkup(r, p), key: const ValueKey('craft-cost')));

    // PIERDES
    out.add(title('PIERDES'));
    final lost = <String>[
      for (final uid in r.consumed)
        if (p.itemByUid(uid) case final it?)
          '${itemNameMarkup(rules, it)} (se destruye con sus mods, pasiva y forja)',
      if (r.replaced != null) 'Reemplaza ${protoEsc(r.replaced!)}',
      for (final l in r.lost) protoEsc(l),
    ];
    out.add(ProtoText(
        key: const ValueKey('craft-lost'),
        lost.isEmpty
            ? protoColor(ProtoColors.green, 'Nada')
            : protoColor(ProtoColors.red, lost.join('<br>'))));
    if (r.error != null) {
      out.add(const SizedBox(height: 6));
      out.add(ProtoText(
          key: const ValueKey('craft-error'),
          protoColor(ProtoColors.red, 'No se puede: ${protoEsc(r.error!)}')));
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
    return parts.isEmpty ? protoColor(ProtoColors.green, 'Nada') : parts.join(' · ');
  }

  String _modList(ItemInstance it) {
    final rules = shop.rules;
    if (it.affixes.isEmpty) return protoColor(ProtoColors.dim, '(sin mods)');
    return [for (final a in it.affixes) '• ${affixMarkup(rules, a)}'].join('<br>');
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
    return lines.isEmpty ? protoColor(ProtoColors.dim, '(sin mods)') : lines.join('<br>');
  }
}
