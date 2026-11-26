import 'weapon_compare_view.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import '../domain/item_names.dart';

import '../../../app/design/design.dart';
import '../../../app/design/ds_layout_host.dart';
import '../../../app/theme/panel_frame.dart';
import '../../../app/theme/panel_widgets.dart';
import '../../../app/theme/proto_colors.dart';
import '../../../app/theme/proto_markup.dart';
import '../../../app/theme/retro_hover_card.dart';
import '../../../app/theme/retro_text.dart';
import '../../../app/theme/retro_theme.dart';
import '../../../app/widgets/action_card.dart';
import '../../../app/widgets/action_row_icon.dart';
import '../../../app/widgets/cost_chip.dart';
import '../../../app/widgets/menu_widgets.dart';
import '../../../app/widgets/pixel_icon.dart';
import '../../../core/layout/layout_doc.dart';
import '../../../game_engine/data/skills_catalog.dart' show kBaseQuebrarIds;
import '../../../game_engine/models/item.dart';
import '../../../game_engine/models/player_profile.dart';
import '../../../game_engine/models/session_action.dart';
import '../../../game_engine/models/weapon.dart';
import '../../../game_engine/rules/craft_rules.dart';
import '../../../game_engine/models/build_plan.dart';
import '../../../game_engine/rules/build_plan_rules.dart';
import '../../../game_engine/rules/weapon_target_rules.dart';
import '../../build_planner/domain/build_wants_of.dart';
import '../../build_planner/presentation/build_fit_badge.dart';
import '../../build_planner/presentation/build_plan_providers.dart';
import '../domain/battle_impact.dart';
import '../domain/craft_help.dart';
import '../domain/inventory_menu.dart' show foldSearch, inventoryMatches;
import '../domain/item_text.dart';
import '../domain/skill_tip.dart';
import '../domain/weapon_text.dart' show fmtNum;
import 'item_grid.dart';
import 'item_hover_tip.dart';
import 'craft_layout.dart';
import 'item_widgets.dart' show CellContent;
import 'shop_sections.dart';
import 'skill_chip.dart';
import 'inventory_strings.dart';
import '../../../core/i18n/strings.dart';

/// Grupos de la mesa (paso 2), en orden.
enum BenchGroup {
  improve,
  transfer,
  remove,
  change;

  String label(Strings s) => s.t('ui.inventory.craft.group.$name.label');
  String note(Strings s) => s.t('ui.inventory.craft.group.$name.note');

  /// Tooltip del encabezado (una línea, `CraftHelp.groups`).
  String get help => CraftHelp.groupText(name);
}

/// Textos de cada operación de la mesa en palabras simples (sin "slot"
/// ni "tier" sin explicar). Ver docs/specs/panels.md § "FUSIÓN".
extension CraftOpText on CraftOp {
  /// Operaciones de la mesa de fusión, en el orden del paso 2.
  static const bench = [
    CraftOp.reroll,
    CraftOp.addAffix,
    CraftOp.upgradeRarity,
    CraftOp.essence,
    CraftOp.transferAffix,
    CraftOp.transferPassive,
    CraftOp.transferSkill,
    CraftOp.restoreQuebrar,
    CraftOp.removeAffix,
    CraftOp.reforge,
  ];

  BenchGroup get group => switch (this) {
        CraftOp.reroll ||
        CraftOp.addAffix ||
        CraftOp.upgradeRarity ||
        CraftOp.essence =>
          BenchGroup.improve,
        CraftOp.transferAffix ||
        CraftOp.transferPassive ||
        CraftOp.transferSkill =>
          BenchGroup.transfer,
        CraftOp.removeAffix => BenchGroup.remove,
        _ => BenchGroup.change,
      };

  /// Key fragment of this operation (`ui.inventory.craft.op.<id>.*`).
  String get textId => switch (this) {
        CraftOp.reroll => 'reroll',
        CraftOp.addAffix => 'add_affix',
        CraftOp.upgradeRarity => 'upgrade_rarity',
        CraftOp.transferAffix => 'transfer_affix',
        CraftOp.transferPassive => 'transfer_passive',
        CraftOp.transferSkill => 'transfer_skill',
        CraftOp.removeAffix => 'remove_affix',
        CraftOp.reforge => 'reforge',
        CraftOp.salvage => 'salvage',
        CraftOp.sell => 'sell',
        CraftOp.salvageAll => 'salvage_all',
        CraftOp.sellAll => 'sell_all',
        CraftOp.salvageSelected => 'salvage_selected',
        CraftOp.sellSelected => 'sell_selected',
        CraftOp.essence => 'essence',
        CraftOp.condense => 'condense',
        CraftOp.restoreQuebrar => 'restore_quebrar',
      };

  String title(Strings s) => s.t('ui.inventory.craft.op.$textId.title');

  /// Explicación de 3-6 palabras para la fila del paso 2.
  String short(Strings s) => switch (this) {
        CraftOp.salvage ||
        CraftOp.sell ||
        CraftOp.salvageAll ||
        CraftOp.sellAll ||
        CraftOp.salvageSelected ||
        CraftOp.sellSelected ||
        CraftOp.condense =>
          line(s),
        _ => s.t('ui.inventory.craft.op.$textId.short'),
      };

  /// Una línea "qué hace".
  String line(Strings s) =>
      s.t('ui.inventory.craft.op.$textId.line', const {'to': '→'});

  /// Texto del botón de confirmar.
  String verb(Strings s) => switch (this) {
        CraftOp.salvage ||
        CraftOp.salvageAll ||
        CraftOp.salvageSelected =>
          s.t('ui.inventory.craft.verb.salvage'),
        CraftOp.sell ||
        CraftOp.sellAll ||
        CraftOp.sellSelected =>
          s.t('ui.inventory.craft.verb.sell'),
        _ => s.t('ui.inventory.craft.op.$textId.verb'),
      };

  bool get needsSource =>
      this == CraftOp.transferAffix ||
      this == CraftOp.transferPassive ||
      this == CraftOp.transferSkill;

  bool get isRandom =>
      this == CraftOp.addAffix ||
      this == CraftOp.reroll ||
      this == CraftOp.upgradeRarity ||
      this == CraftOp.essence;
}

/// Ayuda de los tiers (tooltip junto a los mods).
String tierHelp(Strings s) => s.t('ui.inventory.craft.tier_help');

/// Costo de una operación para la columna derecha del paso 2:
/// `₵300 + 1 Cristal` (`Gratis` si no gasta nada).
String craftCostShort(Strings s, CraftResult r) {
  final parts = [
    if (r.credits > 0) '₵${r.credits}',
    for (final e in r.materials.entries)
      '${e.value} ${e.key.label.split(' ').first}',
  ];
  return parts.isEmpty ? s.t('ui.inventory.craft.free') : parts.join(' + ');
}

/// Mesa de fusión (pestaña FUSIÓN), en 3 pasos: **1 DESTINO** (cuál) →
/// **2 ACCIÓN** (qué hacerle: una línea cada una con el costo o el motivo
/// a la derecha; el detalle explica la que tiene el mouse o el foco) →
/// **3 PREVIA** + CONFIRMAR (solo las elecciones de esa acción a la izquierda —
/// el arma origen y, debajo de ella, sus mods / habilidades — y a la
/// derecha ahora → después, lo que gastás y lo que perdés, con el botón
/// y su motivo). `Enter` confirma, `Esc` vuelve un paso. Ver
/// docs/specs/panels.md § "FUSIÓN".
class CraftBench extends StatefulWidget {
  const CraftBench(
      {super.key,
      required this.shop,
      this.initialOp,
      this.layout,
      this.layoutHooks});

  final ShopContext shop;

  /// Layout fijo (Editor → LAYOUT); `null` = el del catálogo
  /// (editor_layout.md § 6).
  final LayoutDoc? layout;
  final DsLayoutHooks? layoutHooks;

  /// Arranca en el paso 3 con esta operación (y la equipada).
  final CraftOp? initialOp;

  @override
  State<CraftBench> createState() => _CraftBenchState();
}

class _CraftBenchState extends State<CraftBench> {
  Strings get _s => invStrings(context);

  late int _step = widget.initialOp == null ? 0 : 2;
  late CraftOp _op = widget.initialOp ?? CraftOp.reroll;
  String? _target, _source, _base;
  int _pick = 0;

  /// Traer habilidad con los cupos llenos: cuál de las trasladadas se
  /// reemplaza (vale solo para [_replaceFor] = `destino|habilidad`).
  String? _replace, _replaceFor;

  /// Familia del filtro de bases al reforjar (`null` = todas).
  late String? _family = widget.shop.profile.classId;


  /// La destino antes de la última operación (para mostrar qué salió).
  ItemInstance? _lastBefore;
  bool _done = false;

  final _focus = FocusNode(debugLabel: 'craft-bench');

  /// Buscadores de cada lista donde se elige un arma (paso 1: destino;
  /// paso 3: origen que se destruye y base nueva al reforjar).
  final _weaponQ = TextEditingController();
  final _sourceQ = TextEditingController();
  final _baseQ = TextEditingController();

  /// Lo que hace `Enter` en el paso actual (con el foco en la mesa).
  VoidCallback? _enter;

  ShopContext get shop => widget.shop;

  @override
  void dispose() {
    _focus.dispose();
    _weaponQ.dispose();
    _sourceQ.dispose();
    _baseQ.dispose();
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

  /// ¿[it] coincide con el texto de [q]? Mismo criterio que el buscador
  /// del inventario (nombre, tipo, rareza, mods, pasiva, habilidades).
  bool _hit(TextEditingController q, ItemInstance it) =>
      inventoryMatches(shop.rules, q.text, item: it);

  bool _baseHit(WeaponDef w) {
    final words =
        foldSearch(_baseQ.text).split(RegExp(r'\s+')).where((x) => x.isNotEmpty);
    final text = foldSearch('${w.text} ${w.name} ${w.type} ${w.classId}');
    return words.every(text.contains);
  }

  /// Buscador de una grilla de la mesa (el mismo del inventario).
  ItemGridSearch _search(String key, TextEditingController q, String hint) =>
      ItemGridSearch(
          fieldKey: ValueKey(key),
          hint: hint,
          controller: q,
          onChanged: (_) => setState(() {}));

  /// Grilla de armas de la mesa: la misma casilla, ficha y buscador que
  /// el INVENTARIO (design_system.md § "Estructura atómica"). [note]
  /// agrega markup al pie de la ficha.
  ///
  /// Plantilla DsWeaponList (ui_minimal.md § 3): buscador siempre y la
  /// equipada fija arriba. Si [list] no la trae (p. ej. el origen, que
  /// nunca puede ser la equipada) se muestra igual, con candado.
  Widget _weaponGrid(PlayerProfile p, List<ItemInstance> found,
      {required String? selected,
      required String keyPrefix,
      required ValueChanged<ItemInstance> onTap,
      required ItemGridSearch search,
      String? empty,
      String Function(ItemInstance)? note,
      Set<String> Function(BuildPlan plan, BuildPlanRules rules)? stars}) {
    final eq = p.itemByUid(p.equippedUid ?? '');
    final eqIn = eq != null && found.any((it) => it.uid == eq.uid);
    final list = [
      if (eq != null) eq,
      for (final it in found)
        if (it.uid != eq?.uid) it
    ];
    final eqLocked = eq != null && !eqIn;
    return Consumer(builder: (context, ref, _) {
        final plan = ref.watch(buildPlanProvider).plan;
        final fit = ref.watch(buildPlanRulesProvider);
        // ★ de BUILD v2 (build_planner_v2.md § 1.5): mejor candidata como
        // destino y donante sugerido como origen.
        final starred = stars?.call(plan, fit) ?? const <String>{};
        return DsWeaponList(
          rules: shop.rules,
          count: list.length,
          search: search,
          equipped: eq == null ? null : 0,
          keyPrefix: keyPrefix,
          empty: empty,
          cellKey: (i) => ValueKey('$keyPrefix${list[i].uid}'),
          slot: (i) => ItemSlotData(
              content: CellContent.item(list[i]),
              selected: list[i].uid == selected,
              locked: i == 0 && eqLocked,
              buildMatch: starred.contains(list[i].uid) ||
                  (plan.goalCount > 0 && fit.itemFit(plan, list[i]).any)),
          tip: (i, child, focused) {
            final it = list[i];
            final base = note?.call(it);
            final n = starred.contains(it.uid)
                ? '★ ${_s.t('ui.inventory.craft.suggested')}'
                    '${base == null ? '' : '<br>$base'}'
                : base;
            return itemHoverTip(
                rules: shop.rules,
                viewer: p,
                item: it,
                attributes: p.attributes,
                equipped: it.uid == p.equippedUid,
                focused: focused,
                footer: n == null
                    ? null
                    : Container(
                        key: ValueKey('${keyPrefix}tip-${it.uid}'),
                        padding: const EdgeInsets.all(6),
                        color: ProtoColors.bg,
                        // Al ancho de la ficha de arriba (180), no al
                        // de los tooltips de texto (360): si no, se sale.
                        child: RetroTipText(n,
                            maxWidth: RetroType.width(
                                    context, HoverCompareCard.cardWidth) -
                                12)),
                child: child);
          },
          onTap: (i) {
            if (i == 0 && eqLocked) return;
            onTap(list[i]);
          },
        );
      });
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
      source =
          (list.where((i) => i.uid == _source).firstOrNull ?? list.firstOrNull)
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
    if (op == CraftOp.restoreQuebrar) {
      final ok = _replaceFor == '${target.uid}|restore' &&
          target.extraSkills.contains(_replace);
      return CraftAction(op, target.uid, replaceSkillId: ok ? _replace : null);
    }
    String? replace;
    if (skill != null &&
        _replaceFor == '${target.uid}|$skill' &&
        shop.rules.items.needsReplaceChoice(target, skill) &&
        shop.rules.items.replaceableSkills(target).contains(_replace)) {
      replace = _replace;
    }
    return CraftAction(op, target.uid,
        sourceUid: source,
        index: pick,
        skillId: skill,
        replaceSkillId: replace);
  }

  /// Elementos elegibles (mods o habilidades) en markup.
  List<String> _picks(
      PlayerProfile p, ItemInstance target, CraftOp op, String? sourceUid) {
    final rules = shop.rules;
    final source = sourceUid == null ? null : p.itemByUid(sourceUid);
    return switch (op) {
      CraftOp.transferAffix => [
          for (final a in source?.affixes ?? const <AffixRoll>[])
            _sideTagged(a, affixMarkup(rules, a, on: target)),
        ],
      CraftOp.transferSkill => [
          for (final id in source == null
              ? const <String>[]
              : rules.items.skillsOf(source))
            protoEsc(skillName(rules, id)),
        ],
      CraftOp.removeAffix => [
          for (final a in target.affixes)
            _sideTagged(a, affixMarkup(rules, a, on: target)),
        ],
      _ => const [],
    };
  }

  /// `PREFIJO · mod` / `SUFIJO · mod` (mismo nombre que en las fichas).
  String _sideTagged(AffixRoll a, String mod) {
    final side = shop.rules.items.affixOf(a)?.slot;
    if (side == null) return mod;
    return '${protoColor(ProtoColors.sky, affixSideLabel(side))} '
        '${protoColor(ProtoColors.dim, '·')} $mod';
  }

  /// Por qué el mod [i] de [sourceUid] no se puede traer a [target]
  /// (`null` = se puede). Solo motivos del mod, no de costo.
  String? _transferBlock(ItemInstance target, String? sourceUid, int i,
      PlayerProfile p) {
    final s = sourceUid == null ? null : p.itemByUid(sourceUid);
    final a = s?.affixes.elementAtOrNull(i);
    if (a == null) return null;
    return shop.rules.crafting.transferAffixBlock(target, a);
  }

  /// Motivo corto para el paso 2 (con la elección por defecto).
  String? _quickReason(PlayerProfile p, ItemInstance target, CraftOp op) {
    if (op.needsSource && _sources(p, target, op).isEmpty) {
      return switch (op) {
        CraftOp.transferAffix => _s.t('ui.inventory.craft.no_other_with_mods'),
        CraftOp.transferPassive => _s.t('ui.inventory.craft.no_other_with_passive'),
        _ => _s.t('ui.inventory.craft.no_other'),
      };
    }
    if (op == CraftOp.reforge &&
        target.rarity != Rarity.legendario &&
        shop.rules.crafting.reforgeBases(target).isEmpty) {
      return _s.t('ui.inventory.craft.no_bases');
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
          ? _s.t('ui.inventory.craft.no_bases')
          : shop.guards.craft(p, CraftAction.reforge(target.uid, any.id));
    }
    return shop.guards.craft(p, a);
  }

  // ------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final p = shop.profile;
    final items = shop.owned;
    if (items.isEmpty) return Text(_s.t('ui.inventory.craft.no_weapons'));
    final target =
        items.firstWhere((i) => i.uid == _target, orElse: () => items.first);
    _target = target.uid;
    _enter = null;
    final slots = {
      ..._headerSlots(p, target),
      FuseLayout.keys: (_) => _step == 0 ? const KeyHints(back: null) : null,
      FuseLayout.next: (_) => _step == 0
          ? PanelButton(_s.t('ui.inventory.craft.choose'),
              key: const ValueKey('bench-next'),
              accent: ProtoColors.green,
              onPressed: () => _go(1))
          : null,
    };
    return DsLayoutHost(
      spec: FuseLayout.spec,
      doc: widget.layout,
      hooks: widget.layoutHooks,
      slots: slots,
      frame: (context, box, r) {
        final body = switch (_step) {
          0 => _weaponStep(p, items, target,
              footer: r.isEmpty('footer') ? const [] : [r.region('footer')]),
          1 => _opStep(p, target),
          _ => _confirmStep(p, target),
        };
        return Focus(
          focusNode: _focus,
          onKeyEvent: _onKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(context, box, r),
              const SizedBox(height: 6),
              Expanded(
                  child: KeyedSubtree(
                      key: ValueKey('bench-step-$_step'), child: body)),
            ],
          ),
        );
      },
    );
  }

  /// Migas (pasos, se puede volver), lo elegido y contador de
  /// materiales: slots de la barra de arriba (editor_layout.md § 6).
  Map<String, DsSlotBuilder> _headerSlots(
      PlayerProfile p, ItemInstance target) {
    // Los Fragmentos no se usan en la forja (abren Jefes del Abismo).
    final help = CraftHelp(shop.rules.crafting);
    final mats = [
      for (final m in CraftMaterial.values)
        if (!m.isFragment &&
            (m != CraftMaterial.esencia || p.material(m) > 0))
          m,
    ];
    return {
      FuseLayout.crumbs: (_) => StepCrumbs(
            steps: [_s.t('ui.inventory.craft.step.target'), _s.t('ui.inventory.craft.step.action'), _s.t('ui.inventory.craft.step.preview')],
            tips: CraftHelp.stepsText,
            current: _step,
            keyPrefix: 'bench-crumb-',
            onStep: _go,
          ),
      FuseLayout.summary: (_) => _step == 0
          ? null
          : ProtoText(
              key: const ValueKey('bench-summary'),
              '${itemNameMarkup(shop.rules, target)}'
              '${_step == 2 ? ' · <span class="k">${protoEsc(_op.title(_s))}</span>' : ''}'),
      // Un tooltip por material: para qué sirve y dónde se consigue.
      FuseLayout.materials: (_) => Wrap(
            key: const ValueKey('craft-materials'),
            alignment: WrapAlignment.end,
            children: [
              for (var i = 0; i < mats.length; i++) ...[
                if (i > 0) const Text(' · '),
                RetroTooltip(
                  key: ValueKey('craft-mat-${mats[i].name}'),
                  message: help.material(mats[i], p),
                  child: ProtoText(
                      '${mats[i].label.split(' ').first} <b>x${p.material(mats[i])}</b>'),
                ),
              ],
            ],
          ),
    };
  }

  /// La barra de arriba con las regiones del layout.
  Widget _header(BuildContext context, BoxConstraints box, DsRegions r) {
    final summary = r.isEmpty('summary') ? null : r.region('summary');
    final materials = r.isEmpty('materials') ? null : r.region('materials');
    final crumbs = r.isEmpty('crumbs') ? null : r.region('crumbs');
    // Con texto ENORME las migas, lo elegido y los materiales no entran
    // en una fila: van una debajo de la otra.
    // Con poco ancho, igual.
    if (RetroType.settingFactor(context) >= 1.9 ||
        box.maxWidth < RetroType.width(context, 760)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (crumbs != null) crumbs,
          if (summary != null) summary,
          if (materials != null)
            Align(alignment: Alignment.centerRight, child: materials),
        ],
      );
    }
    return Row(
      children: [
        if (crumbs != null) crumbs,
        const SizedBox(width: 12),
        // Lo elegido en los pasos anteriores, al lado de las migas.
        if (summary != null) ...[
          Expanded(child: summary),
          const SizedBox(width: 12),
          // Tope a la mitad: con texto grande se parten en líneas en vez
          // de desbordar.
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: box.maxWidth / 2),
            child: materials ?? const SizedBox(),
          ),
        ] else ...[
          // Sin nada en el medio, los materiales usan ese lugar (y se
          // parten en líneas si no entran).
          const SizedBox(width: 12),
          Expanded(
            child: Align(
                alignment: Alignment.centerRight,
                child: materials ?? const SizedBox()),
          ),
        ],
      ],
    );
  }

  // ------------------------------------------------------------------
  // Piezas de las tarjetas
  // ------------------------------------------------------------------

  static PixelIconKind matIcon(CraftMaterial m) => materialIcon(m);

  static Color matColor(CraftMaterial m) => materialColor(m);

  static PixelIconKind _opIcon(CraftOp op) => switch (op) {
        CraftOp.reroll => PixelIconKind.dice,
        CraftOp.addAffix => PixelIconKind.plus,
        CraftOp.upgradeRarity => PixelIconKind.gem,
        CraftOp.transferAffix => PixelIconKind.arrowIn,
        CraftOp.transferPassive => PixelIconKind.shard,
        CraftOp.transferSkill => PixelIconKind.star,
        CraftOp.removeAffix => PixelIconKind.trash,
        _ => PixelIconKind.anvil,
      };

  static (PixelIconKind, Color) _groupIcon(BenchGroup g) => switch (g) {
        BenchGroup.improve => (PixelIconKind.gem, ProtoColors.gold),
        BenchGroup.transfer => (PixelIconKind.arrowIn, ProtoColors.sky),
        BenchGroup.remove => (PixelIconKind.trash, ProtoColors.red),
        BenchGroup.change => (PixelIconKind.anvil, ProtoColors.orange),
      };

  /// Chip de costo: moneda y cada material con su ícono, en verde lo que
  /// alcanza y en rojo lo que falta.
  /// Costo corto como etiqueta (`₵200 · 1 Prisma`), dorado si alcanza.
  Widget _costTag(CraftResult r, PlayerProfile p) {
    final parts = [
      if (r.credits > 0) '₵${r.credits}',
      for (final e in r.materials.entries)
        '${e.value} ${e.key.label.split(' ').first}',
    ];
    final ok = p.credits >= r.credits &&
        r.materials.entries.every((e) => p.material(e.key) >= e.value);
    return DsActionRow.costTag(parts.isEmpty ? _s.t('ui.inventory.craft.free_upper') : parts.join(' · '),
        affordable: ok);
  }

  CostChip _costChip(CraftResult r, PlayerProfile p) => CostChip([
        if (r.credits > 0)
          CostPart(PixelIconKind.coin, '${r.credits}',
              ok: p.credits >= r.credits),
        for (final e in r.materials.entries)
          CostPart(
              matIcon(e.key), '${e.value} ${e.key.label.split(' ').first}',
              iconColor: matColor(e.key), ok: p.material(e.key) >= e.value),
      ]);


  // ------------------------------------------------------------------
  // Paso 1: ¿qué arma?
  // ------------------------------------------------------------------

  Widget _weaponStep(
      PlayerProfile p, List<ItemInstance> items, ItemInstance target,
      {required List<Widget> footer}) {
    final rules = shop.rules;
    _enter = () => _go(1);
    return PanelSplit(
      listWidth: 480,
      list: [
        _weaponGrid(
          p,
          [
            for (final it in items)
              if (it.uid == target.uid || _hit(_weaponQ, it)) it
          ],
          selected: target.uid,
          keyPrefix: 'bench-weapon-',
          stars: (plan, r) => _bestTarget(plan, r, p),
          search: _search('bench-weapon-search', _weaponQ,
              _s.t('ui.inventory.craft.search_weapon')),
          empty: _s.t('ui.inventory.craft.no_match_weapon'),
          onTap: (it) {
            if (it.uid == target.uid) return _go(1);
            setState(() {
              _target = it.uid;
              _pick = 0;
              _source = null;
            });
            _focus.requestFocus();
          },
        ),
      ],
      detail: PanelDetail(
        footer: footer,
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
          _sourceQ.clear();
          _baseQ.clear();
          _step = 2;
          _lastBefore = null;
          _done = false;
          _focus.requestFocus();
        });
    _enter = () => choose(_op);
    // Una sección por grupo (título + línea fina, sin marco) y una fila
    // DsActionRow por acción (ui_minimal.md § 6): ícono, nombre, una
    // línea y el costo a la derecha; bloqueada en gris con candado y el
    // motivo en la línea. El detalle, en el tooltip.
    Widget card(CraftOp op) {
      final why = _quickReason(p, target, op);
      // Costo con la elección por defecto; si esa no vale (p. ej. el mod
      // depende del origen), se elige en el paso 3.
      final pre = shop.guards.craftPreview(p, _action(p, target, op));
      final (_, gColor) = _groupIcon(op.group);
      final tip = CraftHelp(shop.rules.crafting)
          .op(p, target, op, preview: pre, blocked: why)
          .markup(op.title(_s));
      return RetroHoverCard(
        builder: (ctx) => RetroTipText(tip,
            key: ValueKey('bench-op-tip-${op.name}'),
            maxWidth: RetroType.width(ctx, RetroHoverCard.textWidth)),
        child: DsActionRow(
          key: ValueKey('bench-op-${op.name}'),
          selected: op == _op,
          reason: why,
          icon: actionRowIcon(context, _opIcon(op), gColor,
              locked: why != null),
          title: op.title(_s),
          description: op.short(_s),
          // ★ si el resultado (vista previa) avanza una meta de tu build.
          extra: why == null && pre.error == null && pre.after != null
              ? BuildFitBadge(item: pre.after, before: target)
              : null,
          cost: KeyedSubtree(
            key: ValueKey('bench-op-why-${op.name}'),
            child: why != null
                ? const SizedBox.shrink()
                : pre.error == null
                    ? _costTag(pre, p)
                    : DsActionRow.costTag(_s.t('ui.inventory.craft.step3')),
          ),
          lockedTap: true,
          onTap: () => choose(op),
        ),
      );
    }

    Widget section(BenchGroup g) {
      return Column(
        key: ValueKey('bench-group-${g.name}'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RetroTooltip(message: g.help, child: DsSectionHeader(g.label(_s))),
          for (final op in CraftOpText.bench)
            if (op.group == g) card(op),
        ],
      );
    }

    final s = [for (final g in BenchGroup.values) section(g)];
    // Las teclas scrollean con las tarjetas (con texto ENORME no queda
    // alto fijo para ellas).
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Align(alignment: Alignment.centerRight, child: KeyHints()),
          const SizedBox(height: 4),
          LayoutBuilder(builder: (context, box) {
              final col = RetroType.width(context, 340);
              final w = box.maxWidth;
              final cols = w >= 3 * col + 24
                  ? 3
                  : w >= 2 * col + 12
                      ? 2
                      : 1;
              Widget column(List<Widget> c) => Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: c));
              const gap = SizedBox(width: 12);
              return switch (cols) {
                3 => Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      column([s[0]]),
                      gap,
                      column([s[1]]),
                      gap,
                      column([s[2], s[3]]),
                    ],
                  ),
                2 => Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      column([s[0], s[2]]),
                      gap,
                      column([s[1], s[3]]),
                    ],
                  ),
                _ => Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: s),
              };
            }),
        ],
      ),
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
            {String? value, double indent = 0, bool dimmed = false}) =>
        MenuRow(
          wrap: true,
          key: ValueKey(key),
          selected: sel,
          indent: indent,
          dimmed: dimmed,
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
              style: const TextStyle(color: DsColors.textMuted)),
        );

    final picks =
        _picks(p, target, op, op.needsSource ? action.sourceUid : null);
    // Traer habilidad: cada fila con la ficha de la habilidad (tooltip) y,
    // debajo de la elegida, qué hace (se lee sin mouse).
    final srcItem = op == CraftOp.transferSkill && action.sourceUid != null
        ? p.itemByUid(action.sourceUid!)
        : null;
    final srcSkills =
        srcItem == null ? const <String>[] : rules.items.skillsOf(srcItem);
    final tipStats = shop.preview.withItem(p, target);
    // Traer mod: los que no entran en esta arma, en gris.
    final blocks = [
      for (var i = 0; i < picks.length; i++)
        op == CraftOp.transferAffix
            ? _transferBlock(target, action.sourceUid, i, p)
            : null
    ];
    List<Widget> pickRows(
            {double indent = 0, List<Widget> afterSelected = const []}) =>
        [
          for (var i = 0; i < picks.length; i++)
            if (rules.catalog.skills[srcSkills.elementAtOrNull(i)]
                case final sk?) ...[
              // Sin tooltip (v0.9.7): la ficha de la elegida ya está
              // debajo (`craft-pick-desc`); antes salía dos veces.
              KeyedSubtree(
                key: ValueKey('craft-pick-row-$i'),
                child: Builder(builder: (_) {
                  // Físicas: cuerpo a cuerpo / a distancia según el arma.
                  final why = rules.items.canReceiveSkill(target, sk.id);
                  return row(
                      'craft-pick-$i',
                      '${picks[i]} '
                          '${protoColor(ProtoColors.dim, '(${sk.mp} MP · ${skillKindLabel(sk)})')}',
                      i == action.index,
                      () => _pick = i,
                      indent: indent,
                      dimmed: why != null,
                      value: why == null
                          ? null
                          : protoColor(ProtoColors.red, protoEsc(why)));
                }),
              ),
              Padding(
                padding: EdgeInsets.only(left: indent + 12, bottom: 2),
                child: Align(
                    alignment: Alignment.centerLeft,
                    child: TransferFitMark(profile: p, skillId: sk.id)),
              ),
              if (i == action.index) ...afterSelected,
              if (i == action.index)
                Container(
                  key: const ValueKey('craft-pick-desc'),
                  margin: EdgeInsets.only(left: indent + 12, bottom: 6),
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: ProtoColors.bg.withValues(alpha: 0.6),
                    border: const Border(
                        left: BorderSide(
                            color: ProtoColors.sky,
                            width: RetroTheme.thinBorderWidth)),
                  ),
                  child: ProtoText(skillTipMarkup(sk, stats: tipStats)),
                ),
            ] else if (blocks[i] case final why?)
              // No se puede traer: gris; el motivo en tooltip salvo el
              // obvio (ya lo tiene).
              why == CraftRules.kAlreadyHasAffix
                  ? row('craft-pick-$i', picks[i], i == action.index,
                      () => _pick = i,
                      indent: indent, dimmed: true)
                  : RetroTooltip(
                      key: ValueKey('craft-pick-why-$i'),
                      message: protoEsc(why),
                      child: row('craft-pick-$i', picks[i],
                          i == action.index, () => _pick = i,
                          indent: indent, dimmed: true))
            else
              row('craft-pick-$i', picks[i], i == action.index, () => _pick = i,
                  indent: indent),
        ];

    // Cupos llenos: elegir cuál de las trasladadas se reemplaza (las de
    // la base no se tocan).
    List<Widget> replaceRows() {
      final restore = op == CraftOp.restoreQuebrar;
      final newSkill = restore ? 'restore' : action.skillId;
      if (restore
          ? !(target.quebrarReplaced &&
              target.extraSkills.length > target.rarity.skillSlots)
          : (op != CraftOp.transferSkill ||
              newSkill == null ||
              !rules.items.needsReplaceChoice(target, newSkill))) {
        return const [];
      }
      final replaceable = restore
          ? target.extraSkills
          : rules.items.replaceableSkills(target);
      return [
        Padding(
          padding: const EdgeInsets.only(left: 24),
          child: Text(
              retroText(restore
                  ? _s.t('ui.inventory.craft.replace_quebrar_q')
                  : _s.t('ui.inventory.craft.replace_skill_q')),
              key: const ValueKey('craft-replace-title'),
              style: TextStyle(
                  color: action.replaceSkillId == null
                      ? ProtoColors.red
                      : ProtoColors.gold)),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.only(left: 24, bottom: 8),
          child: CardGrid(
            key: const ValueKey('craft-replace'),
            minWidth: 170,
            children: [
              for (final id in rules.items.skillsOf(target))
                if (rules.catalog.skills[id] case final sk?)
                  RetroTooltip(
                    key: ValueKey('craft-replace-tip-$id'),
                    message: '${CraftHelp.replaceLine(replaceable: replaceable.contains(id), chosen: id == action.replaceSkillId)}'
                        '<br>${skillTipMarkup(sk, stats: tipStats)}',
                    child: ActionCard(
                      key: ValueKey('craft-replace-$id'),
                      title: '<b>${protoEsc(sk.name)}</b>',
                      description: '${sk.mp} MP · ${skillKindLabel(sk)}',
                      selected: id == action.replaceSkillId,
                      reason:
                          replaceable.contains(id) ? null : _s.t('ui.inventory.craft.base_skill'),
                      footer: replaceable.contains(id)
                          ? CostChip.note(id == action.replaceSkillId
                              ? _s.t('ui.inventory.craft.replaced')
                              : kBaseQuebrarIds.contains(id)
                                  ? _s.t('ui.inventory.craft.quebrar_slot')
                                  : _s.t('ui.inventory.craft.transferred'))
                          : null,
                      onTap: () {
                        if (!replaceable.contains(id)) return;
                        setState(() {
                          _replace = id;
                          _replaceFor = '${target.uid}|$newSkill';
                          _lastBefore = null;
                          _done = false;
                        });
                        _focus.requestFocus();
                      },
                    ),
                  ),
            ],
          ),
        ),
      ];
    }

    final list = <Widget>[dim(op.line(_s))];
    if (op.needsSource) {
      final sources = _sources(p, target, op);
      list.add(MenuHeader(_s.t('ui.inventory.craft.source_q')));
      if (sources.isEmpty) {
        list.add(dim(_quickReason(p, target, op) ??
            _s.t('ui.inventory.craft.no_sources')));
      } else {
        list.add(_weaponGrid(
          p,
          [
            for (final it in sources)
              if (it.uid == action.sourceUid || _hit(_sourceQ, it)) it
          ],
          selected: action.sourceUid,
          keyPrefix: 'craft-source-',
          stars: (plan, r) => _donors(plan, r, p, target, op),
          search: _search('craft-source-search', _sourceQ,
              _s.t('ui.inventory.craft.search_source')),
          note: (it) => CraftHelp(rules.crafting).source(it, op),
          onTap: (it) {
            setState(() {
              _source = it.uid;
              _pick = 0;
              _lastBefore = null;
              _done = false;
            });
            _focus.requestFocus();
          },
        ));
        if (!sources.any((it) => _hit(_sourceQ, it))) {
          list.add(dim(_s.t('ui.inventory.craft.no_match_weapon')));
        }
        // Las elecciones del arma elegida, debajo de la grilla.
        final src = p.itemByUid(action.sourceUid ?? '');
        if (op == CraftOp.transferPassive && src?.passiveId != null) {
          list.add(Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Wrap(spacing: 6, runSpacing: 4, children: [
                ProtoText(
                    _s.t('ui.inventory.craft.passive_of', {'name': protoEsc(rules.items.passiveOf(src!)?.text ?? '')})),
                TransferFitMark(profile: p, passiveId: src.passiveId),
              ])));
        }
        if (src != null && op != CraftOp.transferPassive) {
          list.add(Padding(
              padding: const EdgeInsets.only(top: 6),
              child: ProtoText(itemNameMarkup(rules, src),
                  key: const ValueKey('craft-source-name'))));
          if (picks.isEmpty) {
            list.add(Padding(
                padding: const EdgeInsets.only(left: 24),
                child: dim(op == CraftOp.transferSkill
                    ? _s.t('ui.inventory.craft.no_skills')
                    : _s.t('ui.inventory.craft.no_mods_has'))));
          }
          list.addAll(pickRows(indent: 24, afterSelected: replaceRows()));
        }
      }
    }
    if (op == CraftOp.restoreQuebrar) {
      list.addAll(replaceRows());
    }
    if (op == CraftOp.removeAffix) {
      list.add(MenuHeader(_s.t('ui.inventory.craft.remove_q')));
      if (picks.isEmpty) list.add(dim(_s.t('ui.inventory.craft.no_mods_has')));
      list.addAll(pickRows());
    }
    if (op == CraftOp.reforge) {
      list.add(MenuHeader(_s.t('ui.inventory.craft.base_q')));
      list.add(ChoiceCycler<String?>(
        label: _s.t('ui.inventory.craft.family'),
        keyPrefix: 'bench-family-',
        options: [null, ...rules.catalog.classes.keys],
        value: _family,
        display: (id) => id == null
            ? _s.t('ui.inventory.craft.all')
            : (rules.catalog.classes[id]?.name ?? id).toUpperCase(),
        onChanged: (id) => setState(() {
          _family = id;
          _lastBefore = null;
          _done = false;
        }),
      ));
      list.add(const SizedBox(height: 4));
      final bases = _bases(target);
      if (bases.isEmpty) {
        list.add(dim(_s.t('ui.inventory.craft.none_in_family')));
      } else {
        final shown = [
          for (final w in bases)
            if (w.id == action.sourceUid || _baseHit(w)) w
        ];
        // Las bases van en la misma grilla: la casilla de una Común nueva.
        list.add(DsItemGrid(
          rules: rules,
          count: shown.length,
          search:
              _search('bench-base-search', _baseQ, 'BUSCAR: nombre, tipo'),
          cellKey: (i) => ValueKey('bench-base-${shown[i].id}'),
          slot: (i) => ItemSlotData(
              content: CellContent.item(
                  ItemInstance.common(shown[i].id, shown[i].id)),
              selected: shown[i].id == action.sourceUid),
          tip: (i, child, focused) {
            final w = shown[i];
            return RetroTooltip(
                keyboardFocus: focused,
                message: '<b>${protoEsc(w.text)}</b> '
                    '${protoColor(ProtoColors.dim, protoEsc(w.type))} '
                    '${weightTagMarkup(w)}'
                    '${rules.ignoreRequirements ? '' : '<br>${_s.t('ui.inventory.craft.level_short', {'n': w.level})} ${rules.meetsRequirements(p, w) ? protoColor(ProtoColors.green, 'OK') : protoColor(ProtoColors.red, 'Req')}'}',
                child: child);
          },
          onTap: (i) {
            setState(() {
              _base = shown[i].id;
              _lastBefore = null;
              _done = false;
            });
            _focus.requestFocus();
          },
        ));
        if (!bases.any(_baseHit)) {
          list.add(dim(_s.t('ui.inventory.craft.no_match_base')));
        }
      }
    }
    if (list.length == 1) {
      list.add(dim(_s.t('ui.inventory.craft.nothing_to_pick')));
    }
    list.add(const SizedBox(height: 8));
    list.add(const KeyHints());

    return PanelSplit(
      listWidth: 420,
      list: list,
      detail: PanelDetail(
        footer: [
          PanelButton(_s.t('ui.inventory.craft.other_action'),
              key: const ValueKey('bench-back'), onPressed: () => _go(1)),
          ConfirmButton(op.verb(_s),
              key: const ValueKey('craft-confirm'),
              reason: reason,
              cost: r.credits > 0 || r.materials.isNotEmpty
                  ? _costChip(r, p)
                  : null,
              onPressed: confirm),
        ],
        children: _preview(p, target, op, r),
      ),
    );
  }

  List<ItemInstance> get _stash => stashWeapons(shop.controller.stash);

  /// Mejor candidata del arma objetivo principal en el inventario.
  Set<String> _bestTarget(BuildPlan plan, BuildPlanRules r, PlayerProfile p) {
    final t = plan.mainTarget;
    if (t == null) return const {};
    final best = r.targets.best(t, p);
    return best == null || best.percent == 0 ? const {} : {best.item.uid};
  }

  /// Donantes sugeridos (inventario) de lo que le falta a [target] para
  /// el objetivo principal y que [op] puede traer.
  Set<String> _donors(BuildPlan plan, BuildPlanRules r, PlayerProfile p,
      ItemInstance target, CraftOp op) {
    final t = plan.mainTarget;
    if (t == null) return const {};
    final tr = r.targets;
    final out = <String>{};
    for (final q in tr.match(t, target, viewer: p).reqs) {
      if (q.done) continue;
      final ok = switch (op) {
        CraftOp.transferAffix => q.kind == TargetReqKind.mod,
        CraftOp.transferPassive => q.kind == TargetReqKind.passive,
        CraftOp.transferSkill => q.kind == TargetReqKind.skill,
        _ => false,
      };
      if (!ok) continue;
      final d = tr.donor(t, target, q.key, p, stash: _stash);
      if (d != null && !d.inStash) out.add(d.item.uid);
    }
    return out;
  }

  /// `★ Hacha Tronante Épica: 72% → 81%` (vista previa, § 1.5) y, si el
  /// mejor donante está en el alijo, el aviso (nunca se mueve solo).
  Widget _targetLine(PlayerProfile p, ItemInstance before, ItemInstance? after,
          CraftOp op) =>
      Consumer(builder: (context, ref, _) {
        final t = ref.watch(buildPlanProvider).plan.mainTarget;
        if (t == null) return const SizedBox.shrink();
        final tr = ref.watch(buildPlanRulesProvider).targets;
        final a = tr.match(t, before, viewer: p).percent;
        final stashHint = [
          for (final q in tr.match(t, before, viewer: p).reqs)
            if (!q.done &&
                (q.kind == TargetReqKind.mod ||
                    q.kind == TargetReqKind.skill ||
                    q.kind == TargetReqKind.passive))
              if (tr.donor(t, before, q.key, p, stash: _stash)
                  case final d? when d.inStash)
                _s.t('ui.inventory.craft.in_stash', {'req': q.label, 'name': protoEsc(localItemName(shop.rules.items, d.item))}),
        ];
        final text = after == null
            ? '$a%'
            : '$a% → ${tr.match(t, after, viewer: p).percent}%';
        return InfoLine(
            _s.t('ui.inventory.craft.target'),
            '★ ${protoEsc(tr.targetName(t))}: $text'
                '${stashHint.isEmpty ? '' : '<br>${stashHint.join('<br>')}'}',
            key: const ValueKey('craft-target'),
            color: kPlanColor);
      });

  /// Vista previa: lo que gastás y perdés y una tabla ANTES | DESPUÉS.
  List<Widget> _preview(
      PlayerProfile p, ItemInstance target, CraftOp op, CraftResult r) {
    final rules = shop.rules;
    final after = r.after;
    final out = <Widget>[];
    out.add(_targetLine(p, target, after, op));
    final last = _lastBefore;
    if (_done && last != null && last.uid == target.uid) {
      out.add(ProtoText(
          key: const ValueKey('craft-last'),
          last == target
              ? protoColor(ProtoColors.green, _s.t('ui.inventory.craft.done'))
              : '${protoColor(ProtoColors.green, _s.t('ui.inventory.craft.done_now'))} '
                  '${_diffMods(last, target)}'));
    }

    // Lo que cuesta y lo que se pierde, primero: se ve sin bajar.
    out.add(InfoLine(_s.t('ui.inventory.craft.spend'), _spendMarkup(r, p),
        key: const ValueKey('craft-cost'), color: ProtoColors.gold));
    final lost = <String>[
      for (final uid in r.consumed)
        if (p.itemByUid(uid) case final it?)
          _s.t('ui.inventory.craft.consumed', {'name': itemNameMarkup(rules, it)}),
      if (r.replaced != null) _s.t('ui.inventory.craft.replaces', {'name': protoEsc(r.replaced!)}),
      for (final l in r.lost) protoEsc(l),
    ];
    out.add(InfoLine(
        _s.t('ui.inventory.craft.lose'),
        key: const ValueKey('craft-lost'),
        color: ProtoColors.gold,
        lost.isEmpty
            ? protoColor(ProtoColors.green, _s.t('ui.inventory.craft.nothing'))
            : protoColor(ProtoColors.red, lost.join('<br>'))));
    if (r.error != null) {
      out.add(ProtoText(
          key: const ValueKey('craft-error'),
          protoColor(ProtoColors.red, _s.t('ui.inventory.craft.cannot', {'why': protoEsc(r.error!)}))));
    }
    // Lo que entra al arma, con su marca de build (§ 9.6).
    if (op == CraftOp.transferSkill || op == CraftOp.transferPassive) {
      final src = p.itemByUid(r.consumed.firstOrNull ?? '');
      final skill = op == CraftOp.transferSkill ? _action(p, target, op).skillId : null;
      final passive = op == CraftOp.transferPassive ? src?.passiveId : null;
      final name = skill != null
          ? rules.catalog.skills[skill]?.name
          : passive == null
              ? null
              : rules.items.passiveOf(src!)?.text;
      if (name != null) {
        out.add(Padding(
          key: const ValueKey('craft-incoming'),
          padding: const EdgeInsets.only(top: 4),
          child: Wrap(spacing: 6, runSpacing: 4, children: [
            ProtoText(_s.t('ui.inventory.craft.enters', {'name': protoEsc(name)})),
            TransferFitMark(profile: p, skillId: skill, passiveId: passive),
          ]),
        ));
      }
    }
    out.add(const SizedBox(height: 8));

    // ANTES | DESPUÉS en dos columnas.
    final labelW = RetroType.em(context, 14, size: RetroType.small);
    Widget cmp(String label, String before, String after,
            {Key? key, Widget? extra}) =>
        Container(
          key: key,
          padding: const EdgeInsets.symmetric(vertical: 3),
          decoration: const BoxDecoration(
              border:
                  Border(bottom: BorderSide(color: ProtoColors.panelBorder))),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: labelW,
                child: Row(
                  children: [
                    Flexible(
                        child: Text(retroText(label),
                            style: const TextStyle(color: ProtoColors.sky))),
                    if (extra != null) ...[const SizedBox(width: 4), extra],
                  ],
                ),
              ),
              Expanded(child: ProtoText(before)),
              const SizedBox(width: 10),
              Expanded(child: ProtoText(after)),
            ],
          ),
        );
    final random = after == null && op.isRandom;
    final shown = after ?? target;
    final same = protoColor(ProtoColors.dim, '=');
    out.add(cmp('', '<b style="color:#ffd166">${_s.t('ui.inventory.craft.before')}</b>',
        '<b style="color:#ffd166">${_s.t('ui.inventory.craft.after')}</b>${random ? ' ${protoColor(ProtoColors.sky, _s.t('ui.inventory.craft.random'))}' : ''}'));
    final n0 = localItemName(rules.items, target);
    out.add(cmp(
        _s.t('ui.inventory.craft.row.weapon'),
        itemNameMarkup(rules, target),
        after == null || localItemName(rules.items, after) == n0
            ? same
            : itemNameMarkup(rules, after),
        key: const ValueKey('craft-name')));
    if (after != null && after.baseId != target.baseId) {
      final b0 = rules.items.baseOf(target), b1 = rules.items.baseOf(after);
      out.add(cmp(
          _s.t('ui.inventory.craft.row.base'),
          '${protoEsc(b0?.name ?? target.baseId)} '
              '${protoColor(ProtoColors.dim, protoEsc(b0?.type ?? '?'))}',
          '<b>${protoEsc(b1?.name ?? after.baseId)}</b> '
              '${protoColor(ProtoColors.dim, '${protoEsc(b1?.type ?? '?')}${rules.ignoreRequirements ? '' : ' · ${_s.t('ui.inventory.craft.level_short', {'n': b1?.level ?? '?'})}'}')}'
              '${b1 == null || rules.ignoreRequirements ? '' : '<br>${requirementsLineMarkup(b1, p.level, p.attributes)}'}',
          key: const ValueKey('craft-base')));
      // Peso (panels.md § "Peso del arma"): la categoría y qué le cuesta
      // en turnos con la base nueva.
      if (b0 != null && b1 != null) {
        final turn = weightTurnLine(
            rules, shop.preview.withItem(p, after), b1.weight);
        out.add(cmp(
            _s.t('ui.inventory.craft.row.weight'),
            '${weightTagMarkup(b0)} ${protoColor(ProtoColors.dim, fmtNum(b0.weight))}',
            b0.weight == b1.weight
                ? '${weightTagMarkup(b1)} $same'
                : '${weightTagMarkup(b1)} ${protoColor(ProtoColors.dim, fmtNum(b1.weight))} '
                    '${b1.weight < b0.weight ? protoColor(ProtoColors.green, '▲') : protoColor(ProtoColors.red, '▼')}'
                    '<br>${protoColor(ProtoColors.dim, weightTradeoffText(b1))}'
                    '${turn == null ? '' : '<br>${protoColor(ProtoColors.dim, turn)}'}',
            key: const ValueKey('craft-weight')));
      }
    }
    out.add(cmp(
        _s.t('ui.inventory.craft.row.rarity'),
        '<span style="color:${rarityHex(target.rarity)}">${target.rarity.text}</span>',
        after == null || after.rarity == target.rarity
            ? same
            : '<b style="color:${rarityHex(after.rarity)}">${after.rarity.text}</b> '
                '${protoColor(ProtoColors.green, '▲')}'));
    // Mods justo después de Rareza: el cambio se ve sin bajar (panels.md).
    out.add(cmp(
        _s.t('ui.inventory.craft.row.mods'),
        _s.t('ui.inventory.craft.mods_count', {'n': target.modCount, 'max': target.rarity.maxMods}),
        '${_s.t('ui.inventory.craft.mods_count', {'n': shown.modCount, 'max': shown.rarity.maxMods})} '
            '${protoColor(ProtoColors.dim, _s.t('ui.inventory.craft.room_of', {'rarity': shown.rarity.text}))}',
        key: const ValueKey('craft-mods-title'),
        extra: RetroTooltip(
          key: const ValueKey('craft-tier-help'),
          message: '${tierHelp(_s)}<br><br>${affixSidesHelp(shown.rarity)}',
          child: const Text('[?]', style: TextStyle(color: ProtoColors.sky)),
        )));
    out.add(cmp(
        '',
        _modList(target),
        after == null
            ? protoColor(ProtoColors.sky,
                random ? _s.t('ui.inventory.craft.decided_on_confirm') : _s.t('ui.inventory.craft.no_changes'))
            : _sameMods(target, after)
                ? same
                : _diffMods(target, after),
        key: const ValueKey('craft-mods')));
    final pBefore = rules.items.passiveText(target);
    final pAfter = after == null ? pBefore : rules.items.passiveText(after);
    if (pBefore != null || pAfter != null) {
      out.add(cmp(
          _s.t('ui.inventory.craft.row.passive'),
          '<span style="color:$kPassiveHex">${protoEsc(pBefore ?? '—')}</span>',
          pBefore == pAfter
              ? same
              : '<b style="color:$kPassiveHex">${protoEsc(pAfter ?? '—')}</b>',
          key: const ValueKey('craft-passive')));
    }
    final sBefore = rules.items.skillsOf(target);
    final sAfter = after == null ? sBefore : rules.items.skillsOf(after);
    out.add(cmp(
        _s.t('ui.inventory.craft.row.skills'),
        sBefore.map((id) => protoEsc(skillName(rules, id))).join('<br>'),
        '${[
          for (final id in sAfter)
            sBefore.contains(id)
                ? protoEsc(skillName(rules, id))
                : protoColor(ProtoColors.green,
                    '<b>${protoEsc(skillName(rules, id))}</b> ${_s.t('ui.inventory.craft.new_f')} ▲'),
        ].join('<br>')}<br>'
            '${protoColor(ProtoColors.dim, _s.t('ui.inventory.craft.brought', {'n': shown.extraSkills.length, 'max': shown.rarity.skillSlots}))}',
        key: const ValueKey('craft-skills')));
    // Las de DESPUÉS con su ficha (mouse / foco = tooltip).
    out.add(Padding(
      key: const ValueKey('craft-skills-tips'),
      padding: EdgeInsets.only(left: labelW, top: 2, bottom: 4),
      child: SkillChips(
          rules: rules,
          item: shown,
          label: _s.t('ui.inventory.craft.what_they_do'),
          stats: shop.preview.withItem(p, shown),
          isNew: (id) => !sBefore.contains(id)),
    ));
    if (after != null && rules.catalog.weapons.containsKey(after.baseId)) {
      final b = shop.preview.withItem(p, target);
      final a = shop.preview.withItem(p, after);
      String delta(num x0, num x1, String Function(num) f,
          {bool higher = true}) {
        if ((x1 - x0).abs() < 1e-6) return '${f(x1)} $same';
        final up = (x1 > x0) == higher;
        return '<b style="color:${up ? '#7bed9f' : '#ff6b81'}">${f(x1)} '
            '${x1 > x0 ? '▲' : '▼'}</b>';
      }

      String i(num x) => '${x.round()}';
      for (final (l, x0, x1, f) in [
        (_s.t('ui.inventory.craft.stat.atk'), b.attack, a.attack, i),
        (_s.t('ui.inventory.craft.stat.mag'), b.magic, a.magic, i),
        (_s.t('ui.inventory.craft.stat.spd'), b.speed, a.speed, (num x) => x.toStringAsFixed(1)),
        (
          _s.t('ui.inventory.craft.stat.crit'),
          b.critChance,
          a.critChance,
          (num x) => '${(x * 100).round()}%'
        ),
        (_s.t('ui.inventory.craft.stat.def'), b.defense, a.defense, i),
        (_s.t('ui.inventory.craft.stat.hp'), b.maxHp, a.maxHp, i),
      ]) {
        out.add(cmp(l, f(x0), delta(x0, x1, f)));
      }
    }
    if (r.outcomes.isNotEmpty) {
      out.add(const SizedBox(height: 6));
      out.add(
          Text(_s.t('ui.inventory.craft.can_drop'),
              style: const TextStyle(color: ProtoColors.gold)));
      out.add(ProtoText(
          key: const ValueKey('craft-outcomes'),
          protoColor(ProtoColors.sky, protoEsc(r.outcomes.join(' · ')))));
    }
    return out;
  }

  /// `₵N (tienes M) · 1 Cristal de Era (tienes K)`, en rojo lo que falta.
  String _spendMarkup(CraftResult r, PlayerProfile p) {
    String part(bool ok, String t) => ok ? t : protoColor(ProtoColors.red, t);
    final parts = [
      if (r.credits > 0)
        part(p.credits >= r.credits,
            '<b>₵${r.credits}</b> ${_s.t('ui.inventory.craft.have', {'n': '₵${p.credits}'})}'),
      for (final e in r.materials.entries)
        part(p.material(e.key) >= e.value,
            '${e.value} ${e.key.label} ${_s.t('ui.inventory.craft.have', {'n': p.material(e.key)})}'),
    ];
    return parts.isEmpty
        ? protoColor(ProtoColors.green, _s.t('ui.inventory.craft.nothing'))
        : parts.join(' · ');
  }

  bool _sameMods(ItemInstance a, ItemInstance b) =>
      a.affixes.length == b.affixes.length &&
      [for (var i = 0; i < a.affixes.length; i++) a.affixes[i] == b.affixes[i]]
          .every((x) => x);

  String _modList(ItemInstance it) {
    final rules = shop.rules;
    if (it.affixes.isEmpty) return protoColor(ProtoColors.dim, _s.t('ui.inventory.craft.no_mods'));
    return affixGroupsMarkup(rules, it).join('<br>');
  }

  /// Lista de mods después, agrupada por lado (prefijos / sufijos), con
  /// lo nuevo en verde y lo quitado en rojo (en su grupo).
  String _diffMods(ItemInstance before, ItemInstance after) {
    final rules = shop.rules;
    final removed = [
      for (final a in before.affixes)
        if (!after.affixes.contains(a)) a
    ];
    // Los quitados se muestran en su grupo como si siguieran.
    final shown = after.copyWith(affixes: [...after.affixes, ...removed]);
    final lines = shown.affixes.isEmpty
        ? const <String>[]
        : affixGroupsMarkup(rules, shown, line: (a) {
            if (removed.contains(a) && !after.affixes.contains(a)) {
              return '• ${protoColor(ProtoColors.red, '${protoEsc(localAffixText(rules.items, a, on: before))} ${_s.t('ui.inventory.craft.removed')}')}';
            }
            return before.affixes.contains(a)
                ? '• ${affixMarkup(rules, a, on: after)}'
                : '• ${protoColor(ProtoColors.green, '${protoEsc(localAffixText(rules.items, a, on: after))} ${_s.t('ui.inventory.craft.new_m')}')}';
          });
    return lines.isEmpty
        ? protoColor(ProtoColors.dim, _s.t('ui.inventory.craft.no_mods'))
        : lines.join('<br>');
  }
}

/// Ícono de un material (FUSIÓN, CONDENSAR).
PixelIconKind materialIcon(CraftMaterial m) => switch (m) {
        CraftMaterial.esquirla => PixelIconKind.shard,
        CraftMaterial.cristal => PixelIconKind.gem,
        CraftMaterial.prisma => PixelIconKind.prism,
        CraftMaterial.ancla => PixelIconKind.anchor,
        CraftMaterial.fragReloj ||
        CraftMaterial.fragEco ||
        CraftMaterial.fragCorona ||
        CraftMaterial.fragEras =>
          PixelIconKind.shard,
        CraftMaterial.esencia => PixelIconKind.star,
      };

/// Color del ícono de un material.
Color materialColor(CraftMaterial m) => switch (m) {
        CraftMaterial.esquirla => ProtoColors.sky,
        CraftMaterial.cristal => ProtoColors.violet,
        CraftMaterial.prisma => ProtoColors.pink,
        CraftMaterial.ancla => ProtoColors.gold,
        CraftMaterial.fragReloj ||
        CraftMaterial.fragEco ||
        CraftMaterial.fragCorona ||
        CraftMaterial.fragEras =>
          ProtoColors.violet,
        CraftMaterial.esencia => ProtoColors.crimson,
      };
