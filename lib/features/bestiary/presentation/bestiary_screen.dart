import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/design/design.dart';
import '../../../app/theme/panel_frame.dart';
import '../../../game_engine/models/bestiary.dart';
import '../../characters/presentation/characters_providers.dart';
import '../../combat/presentation/game_sprites.dart';
import 'bestiary_view.dart';
import '../../../core/i18n/i18n_providers.dart';

/// El BESTIARIO desde el título (docs/specs/bestiary.md § 4): el de la
/// cuenta, solo lectura.
class BestiaryScreen extends ConsumerStatefulWidget {
  const BestiaryScreen({super.key});

  @override
  ConsumerState<BestiaryScreen> createState() => _BestiaryScreenState();
}

class _BestiaryScreenState extends ConsumerState<BestiaryScreen> {
  BestiaryProgress? _b;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final a = await ref.read(accountRepositoryProvider).load();
    if (mounted) setState(() => _b = a.bestiary);
  }

  @override
  Widget build(BuildContext context) {
    final b = _b;
    final sprites = ref.watch(gameSpritesProvider).valueOrNull;
    return Scaffold(
      body: PanelFrame(
        key: const ValueKey('bestiary-screen'),
        title: ref.t('ui.bestiary.title'),
        width: 1000,
        fill: true,
        help: ref.t('ui.bestiary.help'),
        onClose: () => Navigator.of(context).maybePop(),
        actions: [
          DsButton(ref.t('ui.bestiary.back'),
              key: const ValueKey('bestiary-screen-close'),
              onPressed: () => Navigator.of(context).maybePop()),
        ],
        child: b == null
            ? Text(ref.t('ui.bestiary.loading'),
                style: const TextStyle(color: DsColors.textMuted))
            : BestiaryView(bestiary: b, sprites: sprites),
      ),
    );
  }
}
