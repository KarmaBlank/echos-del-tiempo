import 'package:material_ui/material_ui.dart';

import '../../../../app/design/design.dart';
import '../../../../game_engine/data/fishing_catalog.dart';
import '../../../../game_engine/models/item.dart' show Rarity;
import '../../../../game_engine/models/player_profile.dart';
import '../../../../game_engine/rules/fishing_rules.dart';
import '../../../../game_engine/rules/farming_rules.dart';
import '../../../inventory/presentation/item_widgets.dart';

/// Color de una rareza de pez (los de las armas).
Color fishRarityColor(FishRarity r) => RarityColors.of(switch (r) {
      FishRarity.comun => Rarity.comun,
      FishRarity.raro => Rarity.raro,
      FishRarity.epico => Rarity.epico,
      FishRarity.legendario => Rarity.legendario,
    });

/// Línea compacta de oficios para PERSONAJE (fishing.md § 3).
Widget lifeSkillsLine(PlayerProfile p) {
  final lvl = FishingRules.level(p);
  final (cur, need) = FishingRules.progress(p.life.fishXp);
  return Padding(
    padding: EdgeInsets.only(top: DsSpace.sm),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const DsSectionHeader('OFICIOS'),
        Text(
            'Pesca nivel $lvl${need > 0 ? ' · $cur/$need XP' : ' · máximo'}'
            ' · ${kRods[p.life.rod]!.name} · Pescados ${p.life.bagTotal}',
            key: const ValueKey('life-fishing'),
            style: DsText.detail()),
        Builder(builder: (_) {
          final cl = FarmingRules.level(p);
          final (cc, cn) = FarmingRules.progress(p.life.farm.xp);
          return Text(
              'Cultivo nivel $cl${cn > 0 ? ' · $cc/$cn XP' : ' · máximo'}'
              ' · ${kFarmTools[p.life.farm.hoe]!.name} · Cosechas ${p.life.farm.cropTotal}',
              key: const ValueKey('life-farming'),
              style: DsText.detail());
        }),
      ],
    ),
  );
}
