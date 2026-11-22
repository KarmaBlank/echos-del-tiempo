import 'package:material_ui/material_ui.dart';

import '../../../../app/design/design.dart';
import '../../../../game_engine/data/fishing_catalog.dart';
import '../../../../game_engine/models/player_profile.dart';
import '../../../../game_engine/models/session_action.dart' show FarmOp;
import '../../../../game_engine/rules/farming_rules.dart';
import '../map/map_themes.dart';
import '../session_controller.dart';

/// HUD de la herramienta en la mano (farming.md § 4, fishing.md § 4),
/// arriba de las pociones: el aviso compacto (`[E o clic] Arar`, fases de
/// la pesca) y la herramienta equipada. Con la azada, además, el carrusel
/// de semillas y la regadera. Solo en el pueblo; nunca en misiones (el
/// controlador devuelve `activeTool == null`).
class ToolHud extends StatelessWidget {
  const ToolHud({super.key, required this.controller, required this.profile});

  final SessionController controller;
  final PlayerProfile profile;

  static const width = 260.0;

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
      DsButton('Caña: ${rod?.name ?? life.rod}',
          key: const ValueKey('hud-tool-rod'),
          size: DsButtonSize.compact,
          tooltip: many ? 'Cambiar a la siguiente caña' : null,
          onPressed: many ? controller.cycleRod : null),
    ];
  }

  List<Widget> _farm() {
    final f = profile.life.farm;
    final hoe = kFarmTools[f.hoe];
    final can = kFarmTools[f.can];
    final active = f.activeSeed;
    final prev = FarmingRules.prevSeed(profile);
    final next = FarmingRules.nextSeed(profile);
    final canWater = controller.farmOp == FarmOp.water;
    Widget chip(String? id, double size, String key, VoidCallback? onTap) {
      final d = kCrops[id];
      final box = Container(
        key: ValueKey(key),
        width: size,
        height: size,
        color: d == null
            ? DsColors.surfaceSunken
            : FarmPalette.fruit[d.rarity.index],
      );
      if (onTap == null || d == null) return box;
      return DsCard(padding: const EdgeInsets.all(2), onTap: onTap, child: box);
    }

    final d = kCrops[active];
    final many = prev != null && prev != active;
    return [
      Text('Azada: ${hoe?.name ?? f.hoe}',
          key: const ValueKey('hud-tool-hoe'),
          textAlign: TextAlign.center,
          style: DsText.detail()),
      SizedBox(height: DsSpace.xs),
      Row(
        key: const ValueKey('hud-seed-carousel'),
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          chip(
              many ? prev : null, 16, 'hud-seed-prev', controller.prevSeedPick),
          SizedBox(width: DsSpace.sm),
          chip(active, 32, 'hud-seed-current', null),
          SizedBox(width: DsSpace.sm),
          chip(many ? next : null, 16, 'hud-seed-next', controller.cycleSeed),
        ],
      ),
      SizedBox(height: DsSpace.xs),
      Text(d == null ? 'Sin semillas' : '${d.seedName} ×${f.seedCount(d.id)}',
          key: const ValueKey('hud-seed-name'),
          textAlign: TextAlign.center,
          style: DsText.body()),
      Text('[Q] o rueda: otra semilla',
          textAlign: TextAlign.center, style: DsText.detail()),
      SizedBox(height: DsSpace.xs),
      DsButton('Regadera: ${can?.name ?? f.can}',
          key: const ValueKey('hud-tool-can'),
          size: DsButtonSize.compact,
          tooltip: canWater ? 'Regar la parcela de enfrente' : null,
          onPressed: canWater ? controller.farmWaterClick : null),
    ];
  }
}
