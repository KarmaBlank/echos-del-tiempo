import 'package:material_ui/material_ui.dart';

import '../../../../app/design/design.dart';
import '../../../../core/i18n/catalog_text.dart';
import '../../../../game_engine/data/bait_catalog.dart';
import '../../../../game_engine/data/fishing_catalog.dart';
import '../../../../game_engine/models/player_profile.dart';
import '../../../../game_engine/data/mine_catalog.dart';
import '../../../../game_engine/rules/profession_gear_rules.dart';
import '../../../../game_engine/rules/farming_rules.dart';
import '../../../../game_engine/rules/mining_rules.dart';
import '../panels/life_icon.dart';
import '../session_controller.dart';
import '../world_strings.dart';

/// Aviso de una línea de la herramienta en la mano (`[E o clic] Arar`,
/// fases de la pesca): abajo al centro, de ancho [ToolHud.width]. Nunca se
/// corta: la caja crece en alto.
class ToolPrompt extends StatelessWidget {
  const ToolPrompt({super.key, required this.controller});

  final SessionController controller;

  @override
  Widget build(BuildContext context) {
    final prompt = controller.toolPrompt;
    if (controller.activeTool == null || prompt == null) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      width: ToolHud.width,
      child: Center(
        child: DsCard(
          padding:
              EdgeInsets.symmetric(horizontal: DsSpace.sm, vertical: DsSpace.xs),
          // Never truncated: the box wraps to fit (₵N = gold coin).
          child: DsGoldText(prompt,
              key: const ValueKey('hud-tool-prompt'),
              textAlign: TextAlign.center,
              style: DsText.subtitle(DsColors.reward)),
        ),
      ),
    );
  }
}

/// HUD de la herramienta en la mano (farming.md § 2.5, fishing.md § 4):
/// desde v0.49.21 una columna en el margen derecho, bajo el reloj del día,
/// una herramienta por fila (ícono + rótulo corto + cantidad), la elegida
/// con borde dorado. Ancho [columnWidth] y alto de fila [rowHeight] fijos:
/// no corre nada del HUD. Solo en el pueblo; nunca en misiones (el
/// controlador devuelve `activeTool == null`).
class ToolHud extends StatelessWidget {
  const ToolHud({super.key, required this.controller, required this.profile});

  final SessionController controller;
  final PlayerProfile profile;

  /// Ancho del aviso de abajo al centro ([ToolPrompt]).
  static const width = 480.0;

  /// Ancho de la columna y alto de cada fila.
  static const columnWidth = 200.0, rowHeight = 34.0;

  /// Íconos: herramientas y semilla en uso; vecinas del carrusel.
  static const iconSize = 24.0, neighborSize = 14.0;

  @override
  Widget build(BuildContext context) {
    final tool = controller.activeTool;
    if (tool == null) return const SizedBox.shrink();
    return SizedBox(
      key: const ValueKey('hud-tool'),
      width: columnWidth,
      child: switch (tool) {
        ActiveTool.rod => _rod(context),
        ActiveTool.mine => _mine(context),
        ActiveTool.hoe => _farm(context),
      },
    );
  }

  /// Una fila: ícono, rótulo (se achica antes que cortarse) y cantidad.
  Widget _row(
      {required String key,
      required Widget icon,
      required String label,
      String? count,
      bool selected = false,
      bool dim = false,
      VoidCallback? onTap,
      String? tip}) {
    final color = dim ? DsColors.textSecondary : DsColors.text;
    final card = DsCard(
      key: ValueKey(key),
      selected: selected,
      padding: EdgeInsets.symmetric(horizontal: DsSpace.xs),
      onTap: onTap,
      child: Row(children: [
        Opacity(opacity: dim ? 0.4 : 1, child: icon),
        SizedBox(width: DsSpace.xs),
        Expanded(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(label,
                maxLines: 1, softWrap: false, style: DsText.subtitle(color)),
          ),
        ),
        if (count != null) ...[
          SizedBox(width: DsSpace.xs),
          Text(count, maxLines: 1, softWrap: false, style: DsText.body(color)),
        ],
      ]),
    );
    return Padding(
      padding: EdgeInsets.only(top: DsSpace.xs),
      child: SizedBox(
          width: columnWidth,
          height: rowHeight,
          child: tip == null ? card : card.tip(tip)),
    );
  }

  Widget _icon(String id, LifeIconKind kind, {Key? key}) => SizedBox(
      width: iconSize,
      height: iconSize,
      child: LifeIcon(id, kind, key: key, size: iconSize));

  static const _noIcon = SizedBox(width: iconSize, height: iconSize);

  /// Mine column (mining_smithing.md § 1.6): PICO (or TALADRO) | ANTORCHA |
  /// BOMBA | ACEITE, like ABONO and CEBO. Click picks the row; 1–4 and R
  /// too.
  Widget _mine(BuildContext context) {
    final life = profile.life;
    final tool = MiningRules.tool(profile);
    final hand = controller.mineHand;
    Widget slot(MineHand h, String key, String icon, String name,
        String? count, String tip) {
      return _row(
          key: key,
          icon: _icon(icon, LifeIconKind.herramienta),
          label: name,
          count: count,
          dim: count == '×0',
          selected: hand == h,
          onTap: () => controller.selectMineHand(h),
          tip: tip);
    }

    final boost = controller.boostLeft;
    return Column(
      key: const ValueKey('hud-mine-bar'),
      mainAxisSize: MainAxisSize.min,
      children: [
        slot(
            MineHand.pick,
            'hud-mine-pick',
            tool.id,
            context.t(tool.drill
                ? 'ui.world.tools.drill'
                : 'ui.world.tools.pick'),
            null,
            context.t('ui.world.tools.pick_tip', {
              'name': context.t('data.materials.smith.${tool.id}.name'),
              'tier': tool.tier,
            })),
        slot(MineHand.torch, 'hud-mine-torch', kMineTorch,
            context.t('ui.world.tools.torch'), '×${life.ore(kMineTorch)}',
            context.t('ui.world.tools.torch_tip')),
        slot(MineHand.bomb, 'hud-mine-bomb', kMineBomb,
            context.t('ui.world.tools.bomb'), '×${life.ore(kMineBomb)}',
            context.t('ui.world.tools.bomb_tip')),
        slot(
            MineHand.oil,
            'hud-mine-oil',
            kVeinOil,
            context.t('ui.world.tools.oil'),
            boost > 0 ? '${boost}s' : '×${life.ore(kVeinOil)}',
            context.t('ui.world.tools.oil_tip')),
      ],
    );
  }

  Widget _rod(BuildContext context) {
    final life = profile.life;
    final rod = kRods[life.rod];
    final many = life.rods.length > 1;
    return Column(
        key: const ValueKey('hud-rod-bar'),
        mainAxisSize: MainAxisSize.min,
        children: [
          _row(
              key: 'hud-tool-rod',
              icon: _icon(life.rod, LifeIconKind.herramienta),
              label: rod?.name ?? life.rod,
              selected: true,
              onTap: many ? controller.cycleRod : null,
              tip: many ? context.t('ui.world.tools.next_rod') : null),
          _bait(context),
        ]);
  }

  /// CEBO row (fishing.md § 14.5), like ABONO: icon, "Cebo" and the
  /// count; click (or F) picks the next owned bait; best by default.
  Widget _bait(BuildContext context) {
    final id = controller.activeBait;
    final b = id == null ? null : kBaits[id];
    final n = id == null ? 0 : profile.life.baitCount(id);
    final name = b == null ? '' : CatalogText.of(baitNameKey(b.id), b.name);
    final tip = b == null
        ? context.t('ui.world.tools.no_bait_tip')
        : controller.ownedBaits.length > 1
            ? context.t('ui.world.tools.bait_tip_more', {'name': name})
            : name;
    return _row(
        key: 'hud-tool-bait',
        icon: b == null
            ? _noIcon
            : _icon('cebo_${b.id}', LifeIconKind.pescado,
                key: const ValueKey('hud-bait-icon')),
        label: context.t('ui.world.tools.bait'),
        count: b == null ? null : '×$n',
        onTap: controller.ownedBaits.length > 1 ? controller.cycleBait : null,
        tip: tip);
  }
  /// Sprite id of a plantable (crop seed, weapon seed or a living weapon
  /// to replant, profession_gear.md § 3.5).
  String? _seedIcon(String? id) {
    if (id == null) return null;
    if (kCrops[id] case final c?) return 'semilla_${c.id}';
    if (kWeaponSeeds.containsKey(id)) return 'semilla_$id';
    if (id.startsWith(kRegrowItem)) {
      final it = profile.itemByUid(id.substring(kRegrowItem.length));
      final g = it == null ? null : GearRules.defOf(it);
      return g?.sprite;
    }
    return null;
  }

  String _seedName(String id) => controller.plantableName(id);

  int _seedCount(String id) => kCrops.containsKey(id)
      ? profile.life.farm.seedCount(id)
      : kWeaponSeeds.containsKey(id)
          ? profile.life.farm.wseedCount(id)
          : 1;

  Widget _farm(BuildContext context) {
    final f = profile.life.farm;
    final hoe = kFarmTools[f.hoe];
    final can = kFarmTools[f.can];
    final hand = controller.farmHand;
    final active = FarmingRules.activeSeed(profile);
    final prev = FarmingRules.prevSeed(profile);
    final next = FarmingRules.nextSeed(profile);
    final many = prev != null && prev != active;
    final fert = kFertilizers[controller.farmFert];

    // Carrusel: la semilla en uso al centro, las vecinas chicas.
    Widget chip(String? id, double size, String key, VoidCallback? onTap) {
      final icon = _seedIcon(id);
      final box = SizedBox(
        key: ValueKey(key),
        width: size,
        height: size,
        child: icon == null
            ? const DsSpriteIcon(null, size: 0)
            : LifeIcon(icon, LifeIconKind.semilla, size: size),
      );
      if (onTap == null || icon == null) return box;
      return GestureDetector(onTap: onTap, child: box);
    }

    return Column(
      key: const ValueKey('hud-farm-bar'),
      mainAxisSize: MainAxisSize.min,
      children: [
        _row(
            key: 'hud-tool-hoe',
            icon: _icon(f.hoe, LifeIconKind.herramienta),
            label: context.t('ui.world.tools.hoe'),
            selected: hand == FarmHand.hoe,
            onTap: () => controller.selectFarmHand(FarmHand.hoe),
            tip: context.t('ui.world.tools.hoe_tip', {'name': hoe?.name ?? f.hoe})),
        _row(
            key: 'hud-tool-seed',
            icon: Row(
              key: const ValueKey('hud-seed-carousel'),
              mainAxisSize: MainAxisSize.min,
              children: [
                chip(many ? prev : null, neighborSize, 'hud-seed-prev',
                    controller.prevSeedPick),
                chip(active, iconSize, 'hud-seed-current', null),
                chip(many ? next : null, neighborSize, 'hud-seed-next',
                    controller.cycleSeed),
              ],
            ),
            label: active == null
                ? context.t('ui.world.tools.no_seeds')
                : _seedName(active),
            count: active == null ? null : '×${_seedCount(active)}',
            selected: hand == FarmHand.seed,
            onTap: () => controller.selectFarmHand(FarmHand.seed),
            tip: active == null
                ? context.t('ui.world.tools.no_seeds_tip')
                : context.t('ui.world.tools.seed_tip', {'name': _seedName(active)})),
        _row(
            key: 'hud-tool-can',
            icon: _icon(f.can, LifeIconKind.herramienta),
            label: context.t('ui.world.tools.can'),
            selected: hand == FarmHand.can,
            onTap: () => controller.selectFarmHand(FarmHand.can),
            tip: context.t('ui.world.tools.can_tip', {'name': can?.name ?? f.can})),
        // ABONO (v0.24.4): E con esta fila abona; F también, con cualquier
        // herramienta. Clic en el ícono elige otro abono.
        _row(
            key: 'hud-tool-fert',
            icon: fert == null
                ? _noIcon
                : GestureDetector(
                    key: const ValueKey('hud-fert-pick'),
                    onTap: controller.cycleFert,
                    child: _icon(fert.id, LifeIconKind.semilla)),
            label: context.t('ui.world.tools.fert'),
            count: fert == null ? null : '×${f.fertCount(fert.id)}',
            selected: hand == FarmHand.fert,
            onTap: () => controller.selectFarmHand(FarmHand.fert),
            tip: fert == null
                ? context.t('ui.world.tools.no_fert_tip')
                : controller.ownedFerts.length > 1
                    ? context.t('ui.world.tools.fert_tip_more', {'name': fert.name})
                    : fert.name),
      ],
    );
  }
}