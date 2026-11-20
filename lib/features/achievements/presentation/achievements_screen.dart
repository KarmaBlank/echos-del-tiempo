import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/design/design.dart';
import '../../../app/theme/panel_frame.dart';
import '../../../game_engine/models/achievement.dart';
import '../../characters/presentation/characters_providers.dart';
import 'achievements_view.dart';

/// Las HAZAÑAS desde el menú principal (docs/specs/achievements.md § 7):
/// las de la cuenta, solo lectura (el mismo contenido que la pestaña).
class AchievementsScreen extends ConsumerStatefulWidget {
  const AchievementsScreen({super.key});

  @override
  ConsumerState<AchievementsScreen> createState() =>
      _AchievementsScreenState();
}

class _AchievementsScreenState extends ConsumerState<AchievementsScreen> {
  AchievementProgress? _p;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final a = await ref.read(accountRepositoryProvider).load();
    if (mounted) setState(() => _p = a.achievements);
  }

  @override
  Widget build(BuildContext context) {
    final p = _p;
    return Scaffold(
      body: PanelFrame(
        key: const ValueKey('achievements-screen'),
        title: 'HAZAÑAS',
        width: 1000,
        fill: true,
        help: AchievementsView.help,
        onClose: () => Navigator.of(context).maybePop(),
        actions: [
          DsButton('VOLVER',
              key: const ValueKey('achievements-screen-close'),
              onPressed: () => Navigator.of(context).maybePop()),
        ],
        child: p == null
            ? Text('Cargando...', style: DsText.detail())
            : AchievementsView(progress: p),
      ),
    );
  }
}
