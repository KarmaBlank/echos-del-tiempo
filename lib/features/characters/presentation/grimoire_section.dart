import 'package:material_ui/material_ui.dart';

import '../../../app/theme/proto_colors.dart';
import '../../../app/theme/proto_markup.dart';
import '../../../app/widgets/pixel_icon.dart';
import '../../../app/widgets/section_panel.dart';
import '../../../game_engine/data/summoner_catalog.dart';
import '../../../game_engine/models/player_profile.dart';
import '../../../game_engine/models/player_state.dart';
import '../../../game_engine/rules/progression_rules.dart';
import '../../../game_engine/rules/summon_rules.dart';
import '../../combat/domain/summon_text.dart';
import '../../combat/presentation/scene/summon_sprite.dart';
import 'character_strings.dart';

/// GRIMORIO (docs/specs/summoner.md § 8): las invocaciones que podés
/// invocar con tu arma equipada (y las trasladadas), con sus stats con
/// tu equipo y de dónde salen; y las que te faltan, con los tomos que
/// las dan.
class GrimoireSection extends StatelessWidget {
  const GrimoireSection({super.key, required this.rules, required this.profile});

  final ProgressionRules rules;
  final PlayerProfile profile;

  @override
  Widget build(BuildContext context) {
    final skills = rules.weaponSkills(profile).toSet();
    final has = {
      for (final e in kSummonSkillKind.entries)
        if (skills.contains(e.key)) e.value: e.key,
    };
    if (has.isEmpty && profile.classId != 'maga') return const SizedBox.shrink();
    final d = rules.derivedStats(profile);
    final b = rules.buildOf(profile);
    final w = rules.equippedWeapon(profile);
    final extra = rules.equippedItem(profile)?.extraSkills ?? const <String>[];
    final ids = {...d.mechanics, ...d.keystones};
    final s = charStrings(context);
    return SectionPanel(
      key: const ValueKey('grimoire'),
      icon: PixelIconKind.gem,
      title: s.t('ui.characters.grimoire.title'),
      subtitle: has.isEmpty
          ? s.t('ui.characters.grimoire.none')
          : s.t('ui.characters.grimoire.subtitle',
              {'n': has.length, 'max': SummonRules.maxActive(ids)}),
      children: [
        for (final k in SummonKind.values)
          _row(s, k, has[k], b, d, w.name, extra),
      ],
    );
  }

  Widget _row(Strings s, SummonKind k, String? skillId, PlayerBuild b, DerivedStats d,
      String weapon,
      List<String> extra) {
    final def = kSummons[k]!;
    final col = summonColor(k);
    final String text;
    if (skillId != null) {
      final st = SummonRules.stats(def,
          magic: d.magic,
          maxHp: d.maxHp,
          speed: d.speed,
          crit: d.critChance,
          level: b.level,
          build: b,
          ids: {...d.mechanics, ...d.keystones});
      final duration = st.turns >= kSummonForever
          ? s.t('ui.characters.grimoire.forever')
          : s.t('ui.characters.grimoire.turns', {'n': st.turns});
      final origin = s.t(
          extra.contains(skillId)
              ? 'ui.characters.grimoire.moved_to'
              : 'ui.characters.grimoire.from',
          {'weapon': protoEsc(weapon)});
      text = '<b>${def.name}</b> <span class="k">${def.element.label}</span>'
          '<br>${s.t('ui.characters.grimoire.stats', {
            'hp': st.hp,
            'attack': st.attack,
            'duration': duration,
          })}'
          '<br><span class="k">$origin · ${summonRoleText(def)}</span>';
    } else {
      final inv = kSummonSkillKind.entries.firstWhere((e) => e.value == k).key;
      text = '<span class="k">${s.t('ui.characters.grimoire.missing', {
            'name': def.name,
            'element': def.element.label,
          })}</span><br><span class="k">${summonSourcesText(inv, rules.catalog)}</span>';
    }
    return Padding(
      key: ValueKey('grimoire-${k.name}'),
      padding: const EdgeInsets.only(bottom: 6),
      child: Opacity(
        opacity: skillId == null ? 0.6 : 1,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 14,
              height: 14,
              margin: const EdgeInsets.only(top: 2, right: 6),
              decoration: BoxDecoration(
                color: col,
                border: Border.all(color: ProtoColors.panelBorder),
              ),
            ),
            Expanded(child: ProtoText(text)),
          ],
        ),
      ),
    );
  }
}
