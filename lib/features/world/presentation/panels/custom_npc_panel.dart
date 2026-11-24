import 'package:material_ui/material_ui.dart';

import '../../../../app/design/design.dart';
import '../../../../game_engine/data/biomes_catalog.dart' show kPueblo;
import '../../../../game_engine/data/npc_talk_catalog.dart';
import '../../../../game_engine/models/custom_npc.dart';
import '../../../../game_engine/rules/custom_npc_rules.dart';
import '../../../../game_engine/rules/npc_talk_rules.dart';
import '../session_controller.dart';
import '../session_view.dart';
import '../world_strings.dart';
import 'life_icon.dart';
import 'npc_talk.dart';

/// NPC hecho con datos (docs/specs/npc_editor.md § 6.3): el mismo cuadro
/// de diálogo de los habitantes, con saludo, HABLAR (temas del editor) y,
/// si es invitable, la acción INVITAR de sus temas.
class CustomNpcPanel extends StatefulWidget {
  const CustomNpcPanel(
      {super.key, required this.view, required this.controller});

  final SessionView view;
  final SessionController controller;

  @override
  State<CustomNpcPanel> createState() => _CustomNpcPanelState();
}

class _CustomNpcPanelState extends State<CustomNpcPanel> {
  String? _greet;
  String? _greetTo;
  NpcTalk? _talk;
  String? _answer;

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final id = c.talkCustom;
    final d = id == null ? null : kCustomNpcs[id];
    if (d == null) return const SizedBox.shrink();
    final town = c.townState;
    if (_greetTo != d.id) {
      _greetTo = d.id;
      _greet = NpcTalk.greet(d.id);
      _talk = NpcTalk(d.id);
      _answer = null;
      WidgetsBinding.instance.addPostFrameCallback((_) => c.npcTalked(d.id));
    }
    final talk = _talk!;
    void refresh() => setState(() {});
    final inTown = c.place == kPueblo;
    final canInvite = d.invitable &&
        d.spawn == CustomNpcSpawn.biome &&
        !CustomNpcRules.invited(d, town) &&
        c.place == d.place;
    final actions = TalkActions(
      why: (a) => switch (a) {
        TalkAction.invite => canInvite ? null : '',
        _ => '',
      },
      run: (a) {
        if (a == TalkAction.invite && c.customInvite(d.id)) {
          setState(() => _answer = NpcTalkRules.inviteAccept(d.id));
        }
      },
    );
    final s = worldStrings(context);
    return Align(
      key: const ValueKey('panel-custom-npc'),
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: EdgeInsets.all(DsSpace.md),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1180),
          child: DsDialogueBox(
            portrait: LifeIcon(d.sprite, LifeIconKind.herramienta,
                size: DsDialogueBox.portraitSize),
            name: d.name.text,
            role: d.bio.text,
            text: talk.text(_answer ?? _greet ?? '…'),
            skipLabel: s.t('ui.town.npc.skip'),
            onCancel: c.closePanel,
            choices: talk.active
                ? talk.choices(town, refresh,
                    inTown: inTown, strings: s, actions: actions)
                : [
                    talk.entry(town, refresh, inTown: inTown, strings: s),
                    DsChoice(s.t('ui.town.npc.bye'),
                        key: const ValueKey('custom-npc-bye'),
                        onSelected: c.closePanel),
                  ],
          ),
        ),
      ),
    );
  }
}
