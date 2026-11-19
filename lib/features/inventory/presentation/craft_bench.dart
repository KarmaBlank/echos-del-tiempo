import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/panel_frame.dart';
import '../../../app/theme/panel_widgets.dart';
import '../../../app/theme/proto_colors.dart';
import '../../../app/theme/proto_markup.dart';
import '../../../app/theme/retro_hover_card.dart';
import '../../../app/theme/retro_text.dart';
import '../../../app/theme/retro_theme.dart';
import '../../../app/widgets/action_card.dart';
import '../../../app/widgets/cost_chip.dart';
import '../../../app/widgets/menu_widgets.dart';
import '../../../app/widgets/pixel_icon.dart';
import '../../../app/widgets/section_panel.dart';
import '../../../game_engine/models/item.dart';
import '../../../game_engine/models/player_profile.dart';
import '../../../game_engine/models/session_action.dart';
import '../../../game_engine/models/weapon.dart';
import '../../../game_engine/rules/craft_rules.dart';
import '../../build_planner/presentation/build_fit_badge.dart';
import '../domain/battle_impact.dart';
import '../domain/craft_help.dart';
import '../domain/item_text.dart';
import '../domain/skill_tip.dart';
import '../domain/weapon_text.dart' show fmtNum;
import 'shop_sections.dart';
import 'skill_chip.dart';

/// Grupos de la mesa (paso 2), en orden.
enum BenchGroup {
  improve('MEJORAR', 'cambia los mods de esta arma (con materiales)'),
  transfer('TRASLADAR', 'trae algo de otra arma (esa arma se destruye)'),
  remove('QUITAR', 'saca un mod para hacer lugar'),
  change('CAMBIAR', 'cambia la base del arma');

  const BenchGroup(this.label, this.note);
  final String label;
  final String note;

  /// Tooltip del encabezado (una línea, `CraftHelp.groups`).
  String get help => CraftHelp.groups[name]!;
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
        CraftOp.salvageSelected => 'Desarmar elegidas',
        CraftOp.sellSelected => 'Vender elegidas',
        CraftOp.essence => 'Esencia del Abismo',
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
        CraftOp.essence => 'Mejora los mods fijos',
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
        CraftOp.salvage => 'Destruye el arma y te da materiales de fusión.',
        CraftOp.sell => 'Destruye el arma y te da créditos.',
        CraftOp.salvageAll => 'Desarma todas las armas de una rareza.',
        CraftOp.sellAll => 'Vende todas las armas de una rareza.',
        CraftOp.salvageSelected => 'Desarma las armas que elegiste.',
        CraftOp.sellSelected => 'Vende las armas que elegiste.',
        CraftOp.essence =>
          'Solo legendarios: cada mod fijo se tira 2 veces y queda el mayor; '
              'nunca baja. Usa 1 Esencia del Abismo.',
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
        CraftOp.salvage ||
        CraftOp.salvageAll ||
        CraftOp.salvageSelected =>
          'DESARMAR',
        CraftOp.sell || CraftOp.sellAll || CraftOp.sellSelected => 'VENDER',
        CraftOp.essence => 'USAR ESENCIA',
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
const kTierHelp = '<b>Tiers de los mods</b><br>'
    'Cada mod tiene un tier: <b>T1</b> es el mejor (valores más altos) y '
    '<b>T5</b> el más bajo. Los tiers altos solo salen en armas de nivel '
    'alto (T4 desde nivel 10 … T1 desde nivel 40).<br>'
    '<span class="k">(único)</span> = mod fijo de un legendario.<br>'
    'Cada rareza tiene lugar para N mods: la mitad ofensivos (prefijos) y '
    'la mitad de atributos o defensa (sufijos).';

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

  /// Traer habilidad con los cupos llenos: cuál de las trasladadas se
  /// reemplaza (vale solo para [_replaceFor] = `destino|habilidad`).
  String? _replace, _replaceFor;

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
    // Los Fragmentos no se usan en la forja (abren Jefes del Abismo).
    final help = CraftHelp(shop.rules.crafting);
    final mats = [
      for (final m in CraftMaterial.values)
        if (!m.isFragment &&
            (m != CraftMaterial.esencia || p.material(m) > 0))
          m,
    ];
    final crumbs = StepCrumbs(
      steps: const ['ARMA', 'ACCIÓN', 'CONFIRMAR'],
      tips: CraftHelp.steps,
      current: _step,
      keyPrefix: 'bench-crumb-',
      onStep: _go,
    );
    // Un tooltip por material: para qué sirve y dónde se consigue.
    final materials = Wrap(
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
    );
    // Con texto ENORME las migas, lo elegido y los materiales no entran
    // en una fila: van una debajo de la otra.
    if (RetroType.settingFactor(context) >= 1.9) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          crumbs,
          if (_step > 0)
            ProtoText(
                key: const ValueKey('bench-summary'),
                '${itemNameMarkup(shop.rules, target)}'
                '${_step == 2 ? ' · <span class="k">${protoEsc(_op.title)}</span>' : ''}'),
          Align(alignment: Alignment.centerRight, child: materials),
        ],
      );
    }
    return Row(
      children: [
        crumbs,
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
          child: Align(alignment: Alignment.centerRight, child: materials),
        ),
      ],
    );
  }

  // ------------------------------------------------------------------
  // Piezas de las tarjetas
  // ------------------------------------------------------------------

  static PixelIconKind _matIcon(CraftMaterial m) => switch (m) {
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

  static Color _matColor(CraftMaterial m) => switch (m) {
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
  CostChip _costChip(CraftResult r, PlayerProfile p) => CostChip([
        if (r.credits > 0)
          CostPart(PixelIconKind.coin, '${r.credits}',
              ok: p.credits >= r.credits),
        for (final e in r.materials.entries)
          CostPart(
              _matIcon(e.key), '${e.value} ${e.key.label.split(' ').first}',
              iconColor: _matColor(e.key), ok: p.material(e.key) >= e.value),
      ]);

  /// Efecto corto de [op] sobre [t] (se ve con el mouse sobre la tarjeta).
  String _opPreview(ItemInstance t, CraftOp op) {
    final n = t.modCount, max = t.rarity.maxMods;
    final next = t.rarity.index + 1 < Rarity.values.length
        ? Rarity.values[t.rarity.index + 1].label
        : t.rarity.label;
    return switch (op) {
      CraftOp.reroll => 'Mods $n: valores nuevos al azar',
      CraftOp.addAffix ||
      CraftOp.transferAffix =>
        'Mods $n/$max → ${n + 1}/$max',
      CraftOp.upgradeRarity => 'Rareza ${t.rarity.label} → $next',
      CraftOp.transferPassive => 'Pasiva → la de la otra arma',
      CraftOp.transferSkill =>
        'Habilidades traídas ${t.extraSkills.length} → ${t.extraSkills.length + 1}',
      CraftOp.removeAffix => 'Mods $n/$max → ${n > 0 ? n - 1 : 0}/$max',
      CraftOp.essence => 'Mods fijos: mejor de 2 tiradas, nunca bajan',
      _ => 'Otro tipo de arma, misma rareza',
    };
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
        CardGrid(
          minWidth: 220,
          children: [
            for (final it in items)
              () {
                final color =
                    ProtoColors.parse(rarityHex(it.rarity)) ?? ProtoColors.ink;
                return ActionCard(
                  key: ValueKey('bench-weapon-${it.uid}'),
                  selected: it.uid == target.uid,
                  band: color,
                  bandLabel: it.rarity.label.substring(0, 1),
                  icon: PixelIcon(PixelIconKind.sword,
                      size: RetroType.width(context, 24), color: color),
                  title: itemNameMarkup(rules, it),
                  // ★ si el arma cumple algo de tu build.
                  badge: BuildFitBadge(item: it),
                  description: '${it.rarity.label} · Nv '
                      '${rules.items.baseOf(it)?.level ?? 1} · Mods '
                      '${it.modCount}/${it.rarity.maxMods}',
                  // Las habilidades con su ficha (mouse / foco = tooltip).
                  footer: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (it.uid == p.equippedUid)
                        const Text('EQUIPADA',
                            style: TextStyle(color: ProtoColors.gold)),
                      SkillChips(
                          rules: rules,
                          item: it,
                          label: null,
                          stats: shop.preview.withItem(p, it)),
                    ],
                  ),
                  onTap: () {
                    if (it.uid == target.uid) return _go(1);
                    setState(() {
                      _target = it.uid;
                      _pick = 0;
                      _source = null;
                    });
                    _focus.requestFocus();
                  },
                );
              }(),
          ],
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
    // Una sección enmarcada por grupo (ícono + título + qué hace) y una
    // tarjeta por acción: ícono, nombre, explicación (con el mouse, el
    // efecto) y el chip de costo o el motivo con candado.
    Widget card(CraftOp op) {
      final why = _quickReason(p, target, op);
      // Costo con la elección por defecto; si esa no vale (p. ej. el mod
      // depende del origen), se elige en el paso 3.
      final pre = shop.guards.craftPreview(p, _action(p, target, op));
      final (_, gColor) = _groupIcon(op.group);
      final tip = CraftHelp(shop.rules.crafting)
          .op(p, target, op, preview: pre, blocked: why)
          .markup(op.title);
      // Tooltip con mouse o foco de teclado: qué hace, qué cambia en esta
      // arma, qué cuesta, qué pierdes, por qué está bloqueada y un ejemplo.
      return RetroHoverCard(
        builder: (ctx) => RetroTipText(tip,
            key: ValueKey('bench-op-tip-${op.name}'),
            maxWidth: RetroType.width(ctx, RetroHoverCard.textWidth)),
        child: ActionCard(
        key: ValueKey('bench-op-${op.name}'),
        selected: op == _op,
        disabled: why != null,
        icon: PixelIcon(_opIcon(op),
            size: RetroType.width(context, 24),
            color: why == null ? gColor : ProtoColors.dim),
        title: '<b>${protoEsc(op.title)}</b>',
        description: protoEsc(op.short),
        preview: why == null ? protoEsc(_opPreview(target, op)) : null,
        // ★ si el resultado (vista previa) avanza una meta de tu build.
        badge: why == null && pre.error == null && pre.after != null
            ? BuildFitBadge(item: pre.after, before: target)
            : null,
        footer: KeyedSubtree(
          key: ValueKey('bench-op-why-${op.name}'),
          child: why != null
              ? CostChip.blocked(why)
              : pre.error == null
                  ? _costChip(pre, p)
                  : const CostChip.note('Se puede · eliges en el paso 3'),
        ),
        onTap: () => choose(op),
      ));
    }

    Widget section(BenchGroup g) {
      final (icon, color) = _groupIcon(g);
      return SectionPanel(
        key: ValueKey('bench-group-${g.name}'),
        icon: icon,
        color: color,
        title: g.label,
        subtitle: '— ${g.note}',
        tooltip: g.help,
        children: [
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
              style: const TextStyle(color: ProtoColors.dim)),
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
    List<Widget> pickRows({double indent = 0}) => [
          for (var i = 0; i < picks.length; i++)
            if (rules.catalog.skills[srcSkills.elementAtOrNull(i)]
                case final sk?) ...[
              RetroTooltip(
                message: skillTipMarkup(sk, stats: tipStats),
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
            ] else
              row('craft-pick-$i', picks[i], i == action.index, () => _pick = i,
                  indent: indent),
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
        list.add(RetroTooltip(
            key: ValueKey('craft-source-tip-${it.uid}'),
            message: CraftHelp(rules.crafting).source(it, op),
            child: row('craft-source-${it.uid}', itemNameMarkup(rules, it),
                sel, () {
              _source = it.uid;
              _pick = 0;
            },
                value: protoColor(ProtoColors.dim,
                    '${it.rarity.label} · Nv ${rules.items.baseOf(it)?.level ?? 1}'))));
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
    // Cupos llenos: elegir cuál de las trasladadas se reemplaza (las de
    // la base no se tocan).
    final newSkill = action.skillId;
    if (op == CraftOp.transferSkill &&
        newSkill != null &&
        rules.items.needsReplaceChoice(target, newSkill)) {
      final replaceable = rules.items.replaceableSkills(target);
      list.add(const MenuHeader('¿Qué habilidad reemplazas?'));
      list.add(CardGrid(
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
                  reason: replaceable.contains(id) ? null : 'Habilidad base',
                  footer: replaceable.contains(id)
                      ? CostChip.note(id == action.replaceSkillId
                          ? 'Se reemplaza'
                          : 'Trasladada')
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
      ));
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
            '${protoEsc(w.name)} ${protoColor(ProtoColors.dim, protoEsc(w.type))} '
                '${weightTagMarkup(w)}',
            w.id == action.sourceUid,
            () => _base = w.id,
            value: 'Nv ${w.level} '
                '${rules.meetsRequirements(p, w) ? protoColor(ProtoColors.green, 'OK') : protoColor(ProtoColors.red, 'Req')}'));
      }
    }
    if (list.length == 1) {
      list.add(dim('No hay nada que elegir: mira el resultado a la derecha.'));
    }
    list.add(const SizedBox(height: 8));
    list.add(const KeyHints());

    return PanelSplit(
      listWidth: 420,
      list: list,
      detail: PanelDetail(
        footer: [
          PanelButton('‹ OTRA ACCIÓN',
              key: const ValueKey('bench-back'), onPressed: () => _go(1)),
          ConfirmButton(op.verb,
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

  /// Vista previa: lo que gastás y perdés y una tabla ANTES | DESPUÉS.
  List<Widget> _preview(
      PlayerProfile p, ItemInstance target, CraftOp op, CraftResult r) {
    final rules = shop.rules;
    final after = r.after;
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
    out.add(cmp('', '<b style="color:#ffd166">ANTES</b>',
        '<b style="color:#ffd166">DESPUÉS</b>${random ? ' ${protoColor(ProtoColors.sky, '(al azar)')}' : ''}'));
    final n0 = rules.items.displayName(target);
    out.add(cmp(
        'Arma',
        itemNameMarkup(rules, target),
        after == null || rules.items.displayName(after) == n0
            ? same
            : itemNameMarkup(rules, after),
        key: const ValueKey('craft-name')));
    if (after != null && after.baseId != target.baseId) {
      final b0 = rules.items.baseOf(target), b1 = rules.items.baseOf(after);
      out.add(cmp(
          'Base',
          '${protoEsc(b0?.name ?? target.baseId)} '
              '${protoColor(ProtoColors.dim, protoEsc(b0?.type ?? '?'))}',
          '<b>${protoEsc(b1?.name ?? after.baseId)}</b> '
              '${protoColor(ProtoColors.dim, '${protoEsc(b1?.type ?? '?')} · Nv ${b1?.level ?? '?'}')}'
              '${b1 == null ? '' : '<br>${requirementsLineMarkup(b1, p.level, p.attributes)}'}',
          key: const ValueKey('craft-base')));
      // Peso (panels.md § "Peso del arma"): la categoría y qué le cuesta
      // en turnos con la base nueva.
      if (b0 != null && b1 != null) {
        final turn = weightTurnLine(
            rules, shop.preview.withItem(p, after), b1.weight);
        out.add(cmp(
            'Peso',
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
        'Rareza',
        '<span style="color:${rarityHex(target.rarity)}">${target.rarity.label}</span>',
        after == null || after.rarity == target.rarity
            ? same
            : '<b style="color:${rarityHex(after.rarity)}">${after.rarity.label}</b> '
                '${protoColor(ProtoColors.green, '▲')}'));
    final pBefore = rules.items.passiveText(target);
    final pAfter = after == null ? pBefore : rules.items.passiveText(after);
    if (pBefore != null || pAfter != null) {
      out.add(cmp(
          'Pasiva',
          '<span style="color:$kPassiveHex">${protoEsc(pBefore ?? '—')}</span>',
          pBefore == pAfter
              ? same
              : '<b style="color:$kPassiveHex">${protoEsc(pAfter ?? '—')}</b>',
          key: const ValueKey('craft-passive')));
    }
    final sBefore = rules.items.skillsOf(target);
    final sAfter = after == null ? sBefore : rules.items.skillsOf(after);
    out.add(cmp(
        'Habilidades',
        sBefore.map((id) => protoEsc(skillName(rules, id))).join('<br>'),
        '${[
          for (final id in sAfter)
            sBefore.contains(id)
                ? protoEsc(skillName(rules, id))
                : protoColor(ProtoColors.green,
                    '<b>${protoEsc(skillName(rules, id))}</b> (nueva) ▲'),
        ].join('<br>')}<br>'
            '${protoColor(ProtoColors.dim, 'traídas ${shown.extraSkills.length}/${shown.rarity.skillSlots}')}',
        key: const ValueKey('craft-skills')));
    // Las de DESPUÉS con su ficha (mouse / foco = tooltip).
    out.add(Padding(
      key: const ValueKey('craft-skills-tips'),
      padding: EdgeInsets.only(left: labelW, top: 2, bottom: 4),
      child: SkillChips(
          rules: rules,
          item: shown,
          label: 'Qué hacen:',
          stats: shop.preview.withItem(p, shown),
          isNew: (id) => !sBefore.contains(id)),
    ));
    out.add(cmp(
        'Mods',
        'Mods ${target.modCount}/${target.rarity.maxMods}',
        'Mods ${shown.modCount}/${shown.rarity.maxMods} '
            '${protoColor(ProtoColors.dim, '(lugar de un ${shown.rarity.label})')}',
        key: const ValueKey('craft-mods-title'),
        extra: const RetroTooltip(
          key: ValueKey('craft-tier-help'),
          message: kTierHelp,
          child: Text('[?]', style: TextStyle(color: ProtoColors.sky)),
        )));
    out.add(cmp(
        '',
        _modList(target),
        after == null
            ? protoColor(ProtoColors.sky,
                random ? 'Se decide al confirmar' : '(sin cambios)')
            : _sameMods(target, after)
                ? same
                : _diffMods(target, after),
        key: const ValueKey('craft-mods')));
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
        ('ATQ', b.attack, a.attack, i),
        ('MAG', b.magic, a.magic, i),
        ('VEL', b.speed, a.speed, (num x) => x.toStringAsFixed(1)),
        (
          'CRÍT',
          b.critChance,
          a.critChance,
          (num x) => '${(x * 100).round()}%'
        ),
        ('DEF', b.defense, a.defense, i),
        ('HP', b.maxHp, a.maxHp, i),
      ]) {
        out.add(cmp(l, f(x0), delta(x0, x1, f)));
      }
    }
    if (r.outcomes.isNotEmpty) {
      out.add(const SizedBox(height: 6));
      out.add(
          const Text('PUEDE SALIR', style: TextStyle(color: ProtoColors.gold)));
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
            '<b>₵${r.credits}</b> (tienes ₵${p.credits})'),
      for (final e in r.materials.entries)
        part(p.material(e.key) >= e.value,
            '${e.value} ${e.key.label} (tienes ${p.material(e.key)})'),
    ];
    return parts.isEmpty
        ? protoColor(ProtoColors.green, 'Nada')
        : parts.join(' · ');
  }

  bool _sameMods(ItemInstance a, ItemInstance b) =>
      a.affixes.length == b.affixes.length &&
      [for (var i = 0; i < a.affixes.length; i++) a.affixes[i] == b.affixes[i]]
          .every((x) => x);

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
