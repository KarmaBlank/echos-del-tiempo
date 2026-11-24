import 'package:material_ui/material_ui.dart';

import '../../../../app/design/design.dart';
import '../../../../core/i18n/catalog_text.dart';
import '../../../../game_engine/data/bait_catalog.dart';
import '../../../../game_engine/data/fishing_catalog.dart';
import '../../../../game_engine/models/player_profile.dart';
import '../../../../game_engine/rules/farming_rules.dart';
import '../panels/life_icon.dart';
import '../session_controller.dart';
import '../world_strings.dart';

/// HUD de la herramienta en la mano (farming.md § 2.5, fishing.md § 4),
/// abajo al centro como barra (v0.24.4): el aviso de una línea
/// (`[E o clic] Arar`, fases de la pesca) centrado arriba de la barra y,
/// abajo, la herramienta. En la huerta, tres casilleros: Azada | Semilla
/// (carrusel) | Regadera. Solo en el pueblo; nunca en misiones (el
/// controlador devuelve `activeTool == null`).
class ToolHud extends StatelessWidget {
  const ToolHud({super.key, required this.controller, required this.profile});

  final SessionController controller;
  final PlayerProfile profile;

  /// Ancho de la barra (el aviso usa el mismo).
  static const width = 480.0;

  /// Anchos fijos de los casilleros de la huerta (entran en [width]).
  static const slotW = 104.0, seedW = 140.0;

  /// Íconos: herramientas y semilla en uso; vecinas del carrusel.
  static const iconSize = 32.0, seedSize = 40.0, neighborSize = 24.0;

  @override
  Widget build(BuildContext context) {
    final tool = controller.activeTool;
    if (tool == null) return const SizedBox.shrink();
    final prompt = controller.toolPrompt;
    return SizedBox(
      key: const ValueKey('hud-tool'),
      width: width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (prompt != null) ...[
            DsCard(
              padding: EdgeInsets.symmetric(
                  horizontal: DsSpace.sm, vertical: DsSpace.xs),
              child: Text(prompt,
                  key: const ValueKey('hud-tool-prompt'),
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: DsText.subtitle(DsColors.reward)),
            ),
            SizedBox(height: DsSpace.xs),
          ],
          DsCard(
            padding: EdgeInsets.all(DsSpace.xs),
            child: tool == ActiveTool.rod ? _rod(context) : _farm(context),
          ),
        ],
      ),
    );
  }

  Widget _rod(BuildContext context) {
    final life = profile.life;
    final rod = kRods[life.rod];
    final many = life.rods.length > 1;
    // Casillero como los de la huerta (ícono + nombre), nunca gris.
    final card = DsCard(
      key: const ValueKey('hud-tool-rod'),
      selected: true,
      padding: EdgeInsets.all(DsSpace.xs),
      onTap: many ? controller.cycleRod : null,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        SizedBox(
            height: seedSize,
            child: Center(
                child: LifeIcon(life.rod, LifeIconKind.herramienta,
                    size: iconSize))),
        Text(rod?.name ?? life.rod,
            maxLines: 2,
            textAlign: TextAlign.center,
            style: DsText.subtitle(DsColors.text)),
      ]),
    );
    return Row(
        key: const ValueKey('hud-rod-bar'),
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
              width: seedW,
              child: many ? card.tip(context.t('ui.world.tools.next_rod')) : card),
          SizedBox(width: DsSpace.sm),
          _bait(context),
        ]);
  }

  /// CEBO slot (fishing.md § 14.5), like ABONO: icon, "Cebo [F]" and the
  /// count; click (or F) picks the next owned bait; best by default.
  Widget _bait(BuildContext context) {
    final id = controller.activeBait;
    final b = id == null ? null : kBaits[id];
    final n = id == null ? 0 : profile.life.baitCount(id);
    final count = '×$n';
    final name = b == null ? '' : CatalogText.of(baitNameKey(b.id), b.name);
    final tip = b == null
        ? context.t('ui.world.tools.no_bait_tip')
        : controller.ownedBaits.length > 1
            ? context.t('ui.world.tools.bait_tip_more', {'name': name})
            : name;
    return SizedBox(
      width: slotW,
      child: DsCard(
        key: const ValueKey('hud-tool-bait'),
        padding: EdgeInsets.all(DsSpace.xs),
        onTap: controller.ownedBaits.length > 1 ? controller.cycleBait : null,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          SizedBox(
              height: seedSize,
              child: Center(
                  child: b == null
                      ? const SizedBox(width: iconSize, height: iconSize)
                      : LifeIcon('cebo_${b.id}', LifeIconKind.pescado,
                          key: const ValueKey('hud-bait-icon'),
                          size: iconSize))),
          Text(context.t('ui.world.tools.bait'),
              maxLines: 2,
              textAlign: TextAlign.center,
              style: DsText.subtitle(DsColors.text)),
          if (b != null)
            Text(count,
                key: const ValueKey('hud-bait-count'),
                textAlign: TextAlign.center,
                style: DsText.body()),
        ]),
      ).tip(tip),
    );
  }

  /// Barra de tres casilleros (Azada | Semilla | Regadera), de ancho fijo
  /// para que ningún rótulo se corte. Clic en uno lo deja en la mano (no
  /// hace la labor); el elegido va con borde dorado.
  Widget _farm(BuildContext context) {
    final f = profile.life.farm;
    final hoe = kFarmTools[f.hoe];
    final can = kFarmTools[f.can];
    final hand = controller.farmHand;
    final active = f.activeSeed;
    final prev = FarmingRules.prevSeed(profile);
    final next = FarmingRules.nextSeed(profile);
    final many = prev != null && prev != active;
    final d = kCrops[active];
    final fert = kFertilizers[controller.farmFert];

    // Carrusel: la semilla en uso grande al centro, las vecinas chicas.
    Widget chip(String? id, double size, String key, VoidCallback? onTap) {
      final c = kCrops[id];
      final box = SizedBox(
        key: ValueKey(key),
        width: size,
        height: size,
        child: c == null
            ? const DsSpriteIcon(null, size: 0)
            : LifeIcon('semilla_${c.id}', LifeIconKind.semilla, size: size),
      );
      if (onTap == null || c == null) return box;
      return GestureDetector(onTap: onTap, child: box);
    }

    // Herramientas con la letra de los botones; la semilla, de lectura.
    final hoeName = context.t('ui.world.tools.hoe');
    final canName = context.t('ui.world.tools.can');
    final fertName = context.t('ui.world.tools.fert');
    final toolNames = {hoeName, canName, fertName};
    Widget label(String text) => Text(text,
        maxLines: 2,
        textAlign: TextAlign.center,
        style: toolNames.contains(text)
            ? DsText.subtitle(DsColors.text)
            : DsText.body());

    Widget slot(FarmHand h, double w, String key, List<String> labels,
        String tip, Widget body) {
      return SizedBox(
        width: w,
        child: DsCard(
          key: ValueKey(key),
          selected: hand == h,
          padding: EdgeInsets.all(DsSpace.xs),
          onTap: () => controller.selectFarmHand(h),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(height: seedSize, child: Center(child: body)),
            for (final l in labels) label(l),
          ]),
        ).tip(tip),
      );
    }

    return Row(
      key: const ValueKey('hud-farm-bar'),
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        slot(
            FarmHand.hoe,
            slotW,
            'hud-tool-hoe',
            [hoeName],
            context.t('ui.world.tools.hoe_tip', {'name': hoe?.name ?? f.hoe}),
            LifeIcon(f.hoe, LifeIconKind.herramienta, size: iconSize)),
        slot(
            FarmHand.seed,
            seedW,
            'hud-tool-seed',
            d == null
                ? [context.t('ui.world.tools.no_seeds')]
                : [d.seedName, '×${f.seedCount(d.id)}'],
            d == null
                ? context.t('ui.world.tools.no_seeds_tip')
                : context.t('ui.world.tools.seed_tip', {'name': d.seedName}),
            Row(
              key: const ValueKey('hud-seed-carousel'),
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                chip(many ? prev : null, neighborSize, 'hud-seed-prev',
                    controller.prevSeedPick),
                SizedBox(width: DsSpace.xs),
                chip(active, seedSize, 'hud-seed-current', null),
                SizedBox(width: DsSpace.xs),
                chip(many ? next : null, neighborSize, 'hud-seed-next',
                    controller.cycleSeed),
              ],
            )),
        slot(
            FarmHand.can,
            slotW,
            'hud-tool-can',
            [canName],
            context.t('ui.world.tools.can_tip', {'name': can?.name ?? f.can}),
            LifeIcon(f.can, LifeIconKind.herramienta, size: iconSize)),
        // ABONO (v0.24.4): E con este casillero abona; F también, con
        // cualquier herramienta. Clic en el ícono elige otro abono.
        slot(
            FarmHand.fert,
            slotW,
            'hud-tool-fert',
            [
              fertName,
              if (fert != null) '×${f.fertCount(fert.id)}',
            ],
            fert == null
                ? context.t('ui.world.tools.no_fert_tip')
                : controller.ownedFerts.length > 1
                    ? context.t('ui.world.tools.fert_tip_more', {'name': fert.name})
                    : fert.name,
            fert == null
                ? const SizedBox(width: iconSize, height: iconSize)
                : GestureDetector(
                    key: const ValueKey('hud-fert-pick'),
                    onTap: controller.cycleFert,
                    child: LifeIcon(fert.id, LifeIconKind.semilla,
                        size: iconSize))),
      ],
    );
  }
}
