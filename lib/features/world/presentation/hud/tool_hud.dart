import 'package:material_ui/material_ui.dart';

import '../../../../app/design/design.dart';
import '../../../../game_engine/data/fishing_catalog.dart';
import '../../../../game_engine/models/player_profile.dart';
import '../../../../game_engine/rules/farming_rules.dart';
import '../panels/life_icon.dart';
import '../session_controller.dart';

/// HUD de la herramienta en la mano (farming.md § 4, fishing.md § 4),
/// arriba de las pociones: el aviso compacto (`[E o clic] Arar`, fases de
/// la pesca) y la herramienta equipada. En la huerta, la barra de
/// herramienta activa: Azada | Semilla (carrusel) | Regadera. Solo en el pueblo; nunca en misiones (el
/// controlador devuelve `activeTool == null`).
class ToolHud extends StatelessWidget {
  const ToolHud({super.key, required this.controller, required this.profile});

  final SessionController controller;
  final PlayerProfile profile;

  static const width = 260.0;

  /// Anchos fijos de los casilleros de la huerta (entran en [width]).
  static const slotW = 76.0, seedW = 84.0;

  @override
  Widget build(BuildContext context) {
    final tool = controller.activeTool;
    if (tool == null) return const SizedBox.shrink();
    final prompt = controller.toolPrompt;
    return SizedBox(
      key: const ValueKey('hud-tool'),
      width: width,
      child: DsCard(
        padding: EdgeInsets.all(DsSpace.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (prompt != null)
              Text(prompt,
                  key: const ValueKey('hud-tool-prompt'),
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: DsText.body(DsColors.reward)),
            SizedBox(height: DsSpace.xs),
            if (tool == ActiveTool.rod) ..._rod() else ..._farm(),
          ],
        ),
      ),
    );
  }

  List<Widget> _rod() {
    final life = profile.life;
    final rod = kRods[life.rod];
    final many = life.rods.length > 1;
    return [
      Row(children: [
        LifeIcon(life.rod, LifeIconKind.herramienta, size: 24),
        SizedBox(width: DsSpace.xs),
        Expanded(
          child: DsButton('Caña: ${rod?.name ?? life.rod}',
              key: const ValueKey('hud-tool-rod'),
              size: DsButtonSize.compact,
              tooltip: many ? 'Cambiar a la siguiente caña' : null,
              onPressed: many ? controller.cycleRod : null),
        ),
      ]),
    ];
  }

  /// Barra horizontal de tres casilleros (Azada | Semilla | Regadera), de
  /// ancho fijo para que nada se corte en dos líneas. Clic en uno lo deja
  /// en la mano (no hace la labor); el elegido va con borde dorado.
  List<Widget> _farm() {
    final f = profile.life.farm;
    final hoe = kFarmTools[f.hoe];
    final can = kFarmTools[f.can];
    final hand = controller.farmHand;
    final active = f.activeSeed;
    final prev = FarmingRules.prevSeed(profile);
    final next = FarmingRules.nextSeed(profile);
    final many = prev != null && prev != active;
    final d = kCrops[active];

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

    Widget slot(FarmHand h, double w, String key, String label, String tip,
        Widget? body) {
      return SizedBox(
        width: w,
        child: DsCard(
          key: ValueKey(key),
          selected: hand == h,
          padding: EdgeInsets.all(DsSpace.xs),
          onTap: () => controller.selectFarmHand(h),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            if (body != null) body,
            Text(label,
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.clip,
                textAlign: TextAlign.center,
                style: DsText.detail()),
          ]),
        ).tip(tip),
      );
    }

    return [
      Row(
        key: const ValueKey('hud-farm-bar'),
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          slot(
              FarmHand.hoe,
              slotW,
              'hud-tool-hoe',
              'Azada',
              'Azada: ${hoe?.name ?? f.hoe} · [Tab] o rueda: herramienta',
              LifeIcon(f.hoe, LifeIconKind.herramienta, size: 24)),
          slot(
              FarmHand.seed,
              seedW,
              'hud-tool-seed',
              d == null ? 'Sin semillas' : '×${f.seedCount(d.id)}',
              d == null
                  ? 'Sin semillas: comprá en el comerciante'
                  : '${d.seedName} · [Q] o [ ]: otra semilla',
              Row(
                key: const ValueKey('hud-seed-carousel'),
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  chip(many ? prev : null, 16, 'hud-seed-prev',
                      controller.prevSeedPick),
                  SizedBox(width: DsSpace.xs),
                  chip(active, 24, 'hud-seed-current', null),
                  SizedBox(width: DsSpace.xs),
                  chip(many ? next : null, 16, 'hud-seed-next',
                      controller.cycleSeed),
                ],
              )),
          slot(
              FarmHand.can,
              slotW,
              'hud-tool-can',
              'Regadera',
              'Regadera: ${can?.name ?? f.can}',
              LifeIcon(f.can, LifeIconKind.herramienta, size: 24)),
        ],
      ),
    ];
  }
}
