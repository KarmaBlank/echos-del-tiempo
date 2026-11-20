import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/design/design.dart';
import '../../../app/theme/panel_frame.dart';
import '../../../game_engine/models/player_profile.dart';
import '../../../game_engine/rules/inventory_rules.dart';
import '../../../game_engine/rules/progression_rules.dart';
import '../../world/presentation/session_controller.dart';
import '../domain/stash.dart';
import 'characters_providers.dart';
import 'stash_board.dart';

/// Pantalla `ALIJO COMPARTIDO` (fuera de la sesión): el tablero del alijo
/// ([StashBoard]) sobre la cuenta directa, con el personaje
/// [characterId]. Ver docs/specs/characters.md § 3.
class StashScreen extends ConsumerStatefulWidget {
  const StashScreen({super.key, required this.characterId});

  final String characterId;

  @override
  ConsumerState<StashScreen> createState() => _StashScreenState();
}

class _StashScreenState extends ConsumerState<StashScreen>
    implements StashBoardHost {
  PlayerProfile? _raw;
  PlayerProfile? _p;
  Stash? _stash;
  bool _saving = false;
  String? _notice;

  @override
  ProgressionRules get rules => ref.read(sessionEngineProvider).progression;
  StashRules get _stashRules => StashRules(inventory: rules.inventory);

  @override
  PlayerProfile get profile => _p!;
  @override
  Stash get stash => _stash!;
  @override
  bool get busy => _saving;
  @override
  String? get notice => _notice;

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
      _raw = slot?.profile;
      _p = slot == null ? null : rules.normalize(slot.profile);
      _stash = a.stash;
    });
  }

  /// El perfil a guardar, conservando el aviso de árbol reiniciado que
  /// `normalize` borra (lo muestra la sala al entrar).
  PlayerProfile _keepRefund(PlayerProfile next) {
    final refunded = _raw?.treeRefunded ?? 0;
    if (refunded <= 0) return next;
    return PlayerProfile.fromJson({...next.toJson(), 'tvRef': refunded});
  }

  Future<void> _commit(PlayerProfile p, Stash s) async {
    setState(() {
      _p = p;
      _stash = s;
      _saving = true;
    });
    final save = _keepRefund(p);
    try {
      await ref
          .read(accountRepositoryProvider)
          .update((a) => a.replace(widget.characterId, save).withStash(s));
    } catch (e) {
      if (mounted) setState(() => _notice = 'No se pudo guardar: $e');
    }
    if (mounted) setState(() => _saving = false);
  }

  String? _batch(StashBatch b) {
    if (b.moved.isEmpty) return b.reason ?? 'Nada para mover';
    _notice = b.summary();
    _commit(b.profile, b.stash);
    return null;
  }

  @override
  String? put(List<String> tokens, int tab) =>
      _batch(_stashRules.depositMany(_p!, _stash!, tokens, tab: tab));

  @override
  String? take(List<int> cells) =>
      _batch(_stashRules.withdrawMany(_p!, _stash!, cells));

  @override
  bool moveStash(int from, int to) {
    final next = StashRules.move(_stash!, from, to);
    if (next == null) return false;
    _commit(_p!, next);
    return true;
  }

  @override
  bool moveCharacter(int from, int to) {
    final next = InventoryRules.move(_p!, from, to);
    if (next == null) return false;
    _commit(next, _stash!);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final p = _p, s = _stash;
    final cls = p == null ? '' : rules.catalog.classes[p.classId]?.name ?? p.classId;
    return Scaffold(
      body: PanelFrame(
        key: const ValueKey('stash-screen'),
        title: 'ALIJO COMPARTIDO',
        width: 1000,
        onClose: () => Navigator.of(context).maybePop(),
        help: stashHelp,
        actions: [
          PanelButton('VOLVER',
              key: const ValueKey('stash-close'),
              onPressed: () => Navigator.of(context).maybePop()),
        ],
        child: p == null || s == null
            ? Text('Cargando...', style: DsText.detail())
            : StashBoard(host: this, title: '${p.name} · $cls · Nv ${p.level}'),
      ),
    );
  }
}

/// Ayuda ("?") del alijo, dentro y fuera de la sesión.
const stashHelp =
    'Clic elige, el botón de abajo (o doble clic) lo pasa al otro lado; '
    'clic derecho: Guardar en alijo / Sacar al inventario. ELEGIR marca '
    'varias casillas de un lado; MOVER TODO AL ALIJO lleva todo lo movible.'
    '<br>No se guardan la <b>equipada</b>, la última <b>arma inicial</b> ni '
    'las pociones. Los materiales se apilan hasta ${Stash.maxMaterialStack}. '
    'La pestaña ECOS es para Ecos y materiales de endgame.';