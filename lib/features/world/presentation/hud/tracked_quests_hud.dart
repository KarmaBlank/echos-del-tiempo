import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../../../app/design/design.dart';
import '../../../../game_engine/models/player_profile.dart';
import '../../../../game_engine/models/world_save.dart';
import '../../../../game_engine/rules/quest_track_rules.dart';
import '../../../../game_engine/rules/resident_rules.dart';
import '../../domain/quest_text.dart';
import '../world_strings.dart';

/// Localized name of a weapon type (`ui.town.npc.wtype.<key>`).
String weaponTypeText(Strings s, String type) => s.t(
    'ui.town.npc.wtype.${type.replaceAll('+', '_').replaceAll('á', 'a')}');

/// Name of an order item; forged weapon orders go through i18n
/// ("Sword (lv 10+)").
String questItemText(Strings s, String id) =>
    switch (ResidentRules.parseForgeOrder(id)) {
      (final type, final il)? => s.t('ui.town.npc.forge_journal',
          {'type': weaponTypeText(s, type), 'il': il}),
      null => questItemName(id),
    };

/// Texto de avance de un encargo: "Tenés 1/2 Helecho dulce" o su título.
String questProgressText(Strings s, ActiveQuest a) => a.item == null
    ? activeQuestTitle(s, a)
    : s.t('ui.world.quests.progress', {
        'have': a.have,
        'need': a.need,
        'item': questItemText(s, a.item!)
      });

/// Short title of [a] in the active language (the engine's is es-AR).
String activeQuestTitle(Strings s, ActiveQuest a) => a.item != null
    ? '${a.need} × ${questItemText(s, a.item!)}'
    : [
        for (final r in ResidentRequest.values)
          if (r.label == a.title) requestText(r),
        for (final k in QuestKind.values)
          if (k.label == a.title) questKindText(k),
        a.title,
      ].first;

/// Encargos seguidos en el HUD (roles.md § 8.2): compacto, debajo del
/// reloj; nombre y avance de cada uno. Cuando sube lo que tenés de algo
/// que pide un encargo activo, avisa "Para: Ilda · encargo 3 (1/2)"
/// unos segundos (§ 7.3).
class TrackedQuestsHud extends StatefulWidget {
  const TrackedQuestsHud(
      {super.key,
      required this.profile,
      required this.town,
      required this.onOpen});

  final PlayerProfile profile;
  final TownState town;

  /// Abre el DIARIO.
  final VoidCallback onOpen;

  static const width = 220.0;

  @override
  State<TrackedQuestsHud> createState() => _TrackedQuestsHudState();
}

class _TrackedQuestsHudState extends State<TrackedQuestsHud> {
  Map<String, int> _have = {};
  final _notes = <String>[];
  Timer? _clear;

  Map<String, int> _snapshot() => {
        for (final a in QuestTrackRules.active(widget.profile, widget.town))
          if (a.item != null) a.key: a.have,
      };

  @override
  void initState() {
    super.initState();
    _have = _snapshot();
  }

  @override
  void didUpdateWidget(TrackedQuestsHud old) {
    super.didUpdateWidget(old);
    final now = _snapshot();
    for (final a in QuestTrackRules.active(widget.profile, widget.town)) {
      final before = _have[a.key];
      if (a.item != null && before != null && a.have > before) {
        _notes.add(context.t('ui.world.quests.progress_for', {
          'who': activeQuestWho(a),
          'have': a.have.clamp(0, a.need),
          'need': a.need
        }));
      }
    }
    _have = now;
    if (_notes.isNotEmpty) {
      while (_notes.length > 3) {
        _notes.removeAt(0);
      }
      _clear?.cancel();
      _clear = Timer(const Duration(seconds: 3), () {
        if (mounted) setState(_notes.clear);
      });
    }
  }

  @override
  void dispose() {
    _clear?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tracked = [
      for (final a in QuestTrackRules.active(widget.profile, widget.town))
        if (a.tracked) a,
    ];
    if (tracked.isEmpty && _notes.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      key: const ValueKey('hud-tracked'),
      width: TrackedQuestsHud.width,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final t in _notes)
            Container(
              key: const ValueKey('hud-quest-toast'),
              margin: EdgeInsets.only(bottom: DsSpace.xs),
              padding: EdgeInsets.all(DsSpace.xs),
              decoration: BoxDecoration(
                  color: DsColors.surface,
                  border: Border.all(color: DsColors.reward)),
              child: Text(t,
                  softWrap: true, style: DsText.detail(DsColors.reward)),
            ),
          if (tracked.isNotEmpty)
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: widget.onOpen,
                child: Container(
                  padding: EdgeInsets.all(DsSpace.xs),
                  decoration: BoxDecoration(
                      color: DsColors.surface,
                      border: Border.all(color: DsColors.border)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(context.t('ui.world.hud.journal'),
                          style: DsText.detail(DsColors.textSecondary)),
                      // One row per quest: who and a short count; the
                      // whole line in its tooltip (quest_audit.md § 8).
                      for (final a in tracked) ...[
                        SizedBox(height: DsSpace.xs),
                        Text.rich(
                          TextSpan(children: [
                            TextSpan(
                                text: activeQuestWho(a),
                                style: DsText.detail(a.ready
                                    ? DsColors.statusOk
                                    : DsColors.textTitle)),
                            TextSpan(
                                text: a.item == null
                                    ? ''
                                    : '  ${a.have.clamp(0, a.need)}/${a.need}',
                                style: DsText.detail(DsColors.textSecondary)),
                          ]),
                          key: ValueKey('hud-tracked-${a.key}'),
                          softWrap: true,
                        ).tip(questProgressText(worldStrings(context), a)),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
