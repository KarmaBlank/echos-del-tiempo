import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/design/design.dart';
import '../../../app/theme/panel_frame.dart';
import '../../../game_engine/models/build_plan.dart';
import '../../../game_engine/models/item.dart' show ItemInstance;
import '../../../game_engine/models/player_profile.dart';
import '../../characters/presentation/characters_providers.dart';
import '../../world/presentation/session_controller.dart';
import '../domain/build_wants_of.dart';
import 'build_fit_badge.dart';
import 'build_plan_providers.dart';
import 'build_planner_view.dart';

/// Pantalla BUILD fuera de la sesión (selección de personaje del título,
/// docs/specs/build_planner.md § 4): el plan del personaje
/// [characterId], editable (es solo el plan, no toca el perfil).
class BuildPlannerScreen extends ConsumerStatefulWidget {
  const BuildPlannerScreen({super.key, required this.characterId});

  final String characterId;

  @override
  ConsumerState<BuildPlannerScreen> createState() => _BuildPlannerScreenState();
}

class _BuildPlannerScreenState extends ConsumerState<BuildPlannerScreen> {
  PlayerProfile? _p;
  BuildPlan _plan = BuildPlan.empty;
  String _name = '';
  List<ItemInstance> _stash = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final a = await ref.read(accountRepositoryProvider).load();
    if (!mounted) return;
    final slot = a.byId(widget.characterId);
    setState(() {
      _p = slot == null
          ? null
          : ref.read(sessionEngineProvider).progression.normalize(slot.profile);
      _plan = slot?.plan ?? BuildPlan.empty;
      _name = slot?.displayName ?? '';
      _stash = stashWeapons(a.stash);
    });
  }

  void _changed(BuildPlan plan) {
    setState(() => _plan = plan);
    ref
        .read(buildPlanProvider.notifier)
        .save(plan, characterId: widget.characterId);
  }

  @override
  Widget build(BuildContext context) {
    final p = _p;
    return Scaffold(
      body: PanelFrame(
        key: const ValueKey('build-screen'),
        title: 'BUILD · ${_name.toUpperCase()}',
        width: 1000,
        fill: true,
        help: BuildPlannerView.help,
        onClose: () => Navigator.of(context).maybePop(),
        actions: [
          DsButton('VOLVER',
              key: const ValueKey('build-screen-close'),
              onPressed: () => Navigator.of(context).maybePop()),
        ],
        child: p == null
            ? Text('Cargando...', style: DsText.detail())
            : BuildPlannerView(
                key: const ValueKey('build-planner'),
                rules: ref.watch(buildPlanRulesProvider),
                profile: p,
                plan: _plan,
                stash: _stash,
                onChanged: _changed,
              ),
      ),
    );
  }
}
