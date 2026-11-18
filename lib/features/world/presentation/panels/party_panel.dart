import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../../app/theme/panel_frame.dart';
import '../../../characters/domain/account.dart';
import '../../../characters/presentation/characters_providers.dart';
import '../../../characters/presentation/party_picker.dart';
import '../session_controller.dart';
import '../session_view.dart';

/// Panel PARTY del pueblo (tecla P; docs/specs/solo_party.md § 2.3):
/// agregar o sacar compañeros entre misiones y su AUTO. Solo jugando
/// solo, en el pueblo y sin votación.
class PartyPanel extends ConsumerStatefulWidget {
  const PartyPanel({super.key, required this.view, required this.controller});

  final SessionView view;
  final SessionController controller;

  @override
  ConsumerState<PartyPanel> createState() => _PartyPanelState();
}

class _PartyPanelState extends ConsumerState<PartyPanel> {
  bool _busy = false;

  Future<void> _set(List<String> ids) async {
    setState(() => _busy = true);
    await widget.controller.setParty(ids);
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final view = widget.view;
    final rules = c.engine.progression;
    final Account? account = ref.watch(accountRepositoryProvider).current;
    // En la sala manda lo que se está jugando (nivel al día).
    final inRoom = {
      for (final id in view.companions)
        if (c.slotOf(id) case final slot?) slot: id,
    };
    final candidates = <PartyCandidate>[
      for (final slot in account?.characters ?? const <CharacterSlot>[])
        if (slot.id != account!.selectedId)
          () {
            final live = view.session.players[inRoom[slot.id]]?.profile;
            final p = live ?? rules.normalize(slot.profile);
            return PartyCandidate(
              id: slot.id,
              name: slot.displayName,
              className:
                  rules.catalog.classes[p.classId]?.name ?? p.classId,
              level: p.level,
            );
          }(),
    ];
    return PanelFrame(
      key: const ValueKey('panel-party'),
      title: 'PARTY',
      width: 760,
      help: 'Tus otros personajes de la cuenta te acompañan jugando solo. '
          'Ganan XP y loot propio y se guardan en su ranura. Solo se cambia '
          'en el pueblo, entre misiones.',
      onClose: c.closePanel,
      actions: [
        PanelButton('CERRAR [P]',
            key: const ValueKey('party-close'), onPressed: c.closePanel),
      ],
      child: PartyPicker(
        candidates: candidates,
        selected: [
          for (final id in view.companions)
            if (c.slotOf(id) case final slot?) slot,
        ],
        auto: {
          for (final id in view.auto)
            if (c.slotOf(id) case final slot?) slot,
        },
        enabled: !_busy && c.canEditParty,
        onChanged: (ids) => unawaited(_set(ids)),
        onAuto: (slot, on) => c.setAuto(c.companionIdFor(slot), on),
      ),
    );
  }
}
