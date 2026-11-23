import 'package:material_ui/material_ui.dart';

import '../../../../app/design/design.dart';
import '../../../../game_engine/models/player_profile.dart';
import '../session_controller.dart';
import 'life_items_view.dart';
import 'life_skills_view.dart';

/// Subpestañas de OFICIOS.
enum OficiosSubtab {
  habilidades('HABILIDADES'),
  inventario('INVENTARIO');

  const OficiosSubtab(this.label);
  final String label;
}

/// Pestaña OFICIOS de PERSONAJE (docs/specs/oficio_storage.md § 4): los
/// árboles de cada oficio en HABILIDADES y las bolsas de PESCA, CULTIVO y
/// HERRERÍA en INVENTARIO. Una subpestaña por vez, nunca apiladas.
class OficiosView extends StatefulWidget {
  const OficiosView({
    super.key,
    required this.profile,
    required this.controller,
    required this.inTown,
    this.editBlocked,
    this.initial = OficiosSubtab.habilidades,
  });

  final PlayerProfile profile;
  final SessionController controller;
  final bool inTown;
  final String? editBlocked;
  final OficiosSubtab initial;

  @override
  State<OficiosView> createState() => _OficiosViewState();
}

class _OficiosViewState extends State<OficiosView> {
  late var _sub = widget.initial;

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    return Column(
      key: const ValueKey('oficios-view'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DsTabBar(
          tabs: [
            for (final t in OficiosSubtab.values)
              DsTab(t.label, key: ValueKey('oficios-sub-${t.name}')),
          ],
          index: _sub.index,
          onChanged: (i) => setState(() => _sub = OficiosSubtab.values[i]),
        ),
        SizedBox(height: DsSpace.xs),
        Expanded(
          child: switch (_sub) {
            OficiosSubtab.habilidades => LifeSkillsView(
                profile: widget.profile,
                editBlocked: widget.editBlocked,
                onTake: c.takeLifeNode,
                onReset: c.resetLifeTree),
            OficiosSubtab.inventario => LifeItemsView(
                profile: widget.profile,
                controller: c,
                inTown: widget.inTown),
          },
        ),
      ],
    );
  }
}
